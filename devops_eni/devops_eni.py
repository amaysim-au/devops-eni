#!/usr/bin/env python3.6
import os
import logging
import aws_lambda_logging
import json
import uuid
from dateutil.tz import tzlocal, tzutc
from datetime import datetime
import boto3, botocore

aws_lambda_logging.setup(level=os.environ.get('LOGLEVEL', 'INFO'), env=os.environ.get('ENV'))
logging.info(json.dumps({'message': 'initialising'}))
aws_lambda_logging.setup(level=os.environ.get('LOGLEVEL', 'INFO'), env=os.environ.get('ENV'))

ec2_client = boto3.client('ec2')
ec2_res = boto3.resource('ec2')
asg_client = boto3.client('autoscaling')

eni_description = os.environ['ENI_DESCRIPTION']

def handler(event, context):
    """Handler for devops-eni"""
    correlation_id = get_correlation_id(event=event)
    aws_lambda_logging.setup(level=os.environ.get('LOGLEVEL', 'INFO'), env=os.environ.get('ENV'), correlation_id=correlation_id)

    try:
        logging.debug(json.dumps({'message': 'logging event', 'event': event}))
    except:
        logging.exception(json.dumps({'message': 'logging event'}))
        raise

    instance_id = None
    instance_name = None
    interface_id = None
    try:
        sns_message = json.loads(event["Records"][0]["Sns"]["Message"])
        if sns_message['Event'] != "autoscaling:EC2_INSTANCE_LAUNCH":
            logging.info(json.dumps({'message': 'not a launch event, no action required'}))
            return
        instance_id = sns_message['EC2InstanceId']
        instance_name = get_instance_name(instance_id)
        interface_id = get_interface(eni_desc=eni_description)
        logging.info(json.dumps({'message': 'getting instance info', 'instance_id': instance_id, 'instance_name': instance_name, 'interface_id': interface_id}))
    except:
        logging.exception(json.dumps({'message': 'getting instance info', 'instance_id': instance_id, 'instance_name': instance_name, 'interface_id': interface_id}, default=str))
        raise

    attachment = None
    try:
        attachment = attach_interface(interface_id, instance_id, device_index=1)
        logging.info(json.dumps({'message': 'attaching ENI', 'attachment': attachment}))
    except:
        logging.exception(json.dumps({'message': 'attaching ENI', 'attachment': attachment}, default=str))
        raise

    logging.info(json.dumps({'message': 'done'}))


def get_correlation_id(body=None, payload=None, event=None):
    correlation_id = None
    if event:
        try:
            correlation_id = event['headers']['X-Amzn-Trace-Id'].split('=')[1]
        except:
            pass

    if body:
        try:
            correlation_id = body['trigger_id'][0]
        except:
            pass
    elif payload:
        try:
            correlation_id = payload['trigger_id']
        except:
            pass

    if correlation_id is None:
        correlation_id = str(uuid.uuid4())
    return correlation_id

def get_instance_name(instance_id):
    instance = ec2_res.Instance(instance_id)
    instance_name = next((item['Value'] for item in instance.tags if item['Key'] == 'Name'), None)
    return instance_name
        
def get_interface(eni_desc):
    network_interface_id = None
    network_interfaces = ec2_client.describe_network_interfaces(Filters=[{'Name':'description','Values':[eni_desc]}])
    logging.debug(json.dumps({'message': 'describing network interfaces', 'network_interfaces': network_interfaces}, default=str))
    network_interface_id = network_interfaces['NetworkInterfaces'][0]['NetworkInterfaceId']
    return network_interface_id
    
def attach_interface(network_interface_id,instance_id,device_index):
    attachment = None
    if network_interface_id and instance_id:
        try:
            attach_interface = ec2_client.attach_network_interface (
                NetworkInterfaceId = network_interface_id,
                InstanceId = instance_id,
                DeviceIndex = device_index
            )
            attachment = attach_interface['AttachmentId']
            logging.info(json.dumps({'message': 'attaching interface', 'attachment': attachment}))
        except botocore.exceptions.ClientError:
            logging.exception(json.dumps({'message': 'attaching interface', 'attachment': attachment}, default=str))
            raise
            
        return attachment
