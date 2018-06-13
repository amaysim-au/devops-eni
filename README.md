# DevOps-Eni
Created with [Serverless Python Boilerplate](https://github.com/amaysim-au/serverless-python-boilerplate)

Attaches ENI interfaces of a given description when triggered by an ASG event via SNS.

## Configuration
  * `DEVOPS_R53_SNS_ARN`: this is the ARN of the Autoscaling Group Lifecycle Hook SNS topic for the ASG whose instances you wish to have ENIs attached to
  * `ENI_DESCRIPTION`: the lambda will look for an ENI tagged with `description`: `$ENI_DESCRIPTION` and use the first matching ENI.

## Deploying
To install the required NPM modules for Serverless:
```
make deps
```
To create the virtualenv, install requirements using pip and then create the package.zip for uploading to Lambda:
```
make build
```
To deploy, fill out your `.env` file and then:
```
make deploy
```
