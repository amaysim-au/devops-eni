PACKAGE_DIR=package/package
ARTIFACT_NAME=package.zip
ARTIFACT_PATH=package/$(ARTIFACT_NAME)
ifdef DOTENV
	DOTENV_TARGET=dotenv
else
	DOTENV_TARGET=.env
endif
ifdef AWS_ROLE
	ASSUME_REQUIRED?=assumeRole
endif
ifdef GO_PIPELINE_NAME
	ENV_RM_REQUIRED?=rm_env
else
	USER_SETTINGS=--user $(shell id -u):$(shell id -g)
endif


################
# Entry Points #
################
deps: $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm serverless make _deps

build: $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm lambda-build make _build

deploy: $(ENV_RM_REQUIRED) $(DOTENV_TARGET) $(ASSUME_REQUIRED)
	docker-compose run $(USER_SETTINGS) --rm serverless make _deploy

logs: $(ENV_RM_REQUIRED) $(DOTENV_TARGET) $(ASSUME_REQUIRED)
	docker-compose run $(USER_SETTINGS) --rm serverless make _logs

unitTest: $(ASSUME_REQUIRED) $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm lambda devops_eni.unit_test

smokeTest: $(DOTENV_TARGET) $(ASSUME_REQUIRED)
	docker-compose run $(USER_SETTINGS) --rm serverless make _smokeTest

remove: $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm serverless make _deps _remove

styleTest: $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm pep8 --ignore 'E501,E128' devops_eni/*.py

run: $(DOTENV_TARGET)
	cp -a devops_eni/. $(PACKAGE_DIR)/
	docker-compose run $(USER_SETTINGS) --rm lambda devops_eni.handler '{"Records":[{"EventSource":"aws:sns","EventVersion":"1.0","EventSubscriptionArn":"arn:aws:sns:ap-southeast-2:979598289034:devops-r53:9a2f53dc-0e4d-4d3e-a0d2-a1c1aacff310","Sns":{"Type":"Notification","MessageId":"9a677288-9bb2-5eb2-9f4f-218d08266414","TopicArn":"arn:aws:sns:ap-southeast-2:979598289034:devops-r53","Subject":"Auto Scaling: launch for group \"ad-test4-AutoscalingGroup-6OD14J8RHEPI\"","Message":"{\"Progress\":50,\"AccountId\":\"979598289034\",\"Description\":\"Launching a new EC2 instance: i-05da7fa7c3b5af72c\",\"RequestId\":\"574586c4-bcd4-75aa-f00a-ed14f4ceb8fd\",\"EndTime\":\"2018-02-20T03:09:08.224Z\",\"AutoScalingGroupARN\":\"arn:aws:autoscaling:ap-southeast-2:979598289034:autoScalingGroup:cf35323a-1fb7-46f7-a76c-a70d7190f8c6:autoScalingGroupName/ad-test4-AutoscalingGroup-6OD14J8RHEPI\",\"ActivityId\":\"574586c4-bcd4-75aa-f00a-ed14f4ceb8fd\",\"StartTime\":\"2018-02-20T03:08:36.509Z\",\"Service\":\"AWS Auto Scaling\",\"Time\":\"2018-02-20T03:09:08.224Z\",\"EC2InstanceId\":\"i-046539569b0a70b8a\",\"StatusCode\":\"InProgress\",\"StatusMessage\":\"\",\"Details\":{\"Subnet ID\":\"subnet-b26f6cd6\",\"Availability Zone\":\"ap-southeast-2a\"},\"AutoScalingGroupName\":\"ad-test4-AutoscalingGroup-6OD14J8RHEPI\",\"Cause\":\"At 2018-02-20T03:08:17Z a user request update of AutoScalingGroup constraints to min: 1, max: 2, desired: 2 changing the desired capacity from 1 to 2.  At 2018-02-20T03:08:35Z an instance was started in response to a difference between desired and actual capacity, increasing the capacity from 1 to 2.\",\"Event\":\"autoscaling:EC2_INSTANCE_LAUNCH\"}","Timestamp":"2018-02-20T03:09:08.295Z","SignatureVersion":"1","Signature":"SflWylCsyCfHahOnzYh4KSal7sMvP+J/DSSpcKKh94IX6EzXpJPBLmGmK94jcvGMns9Mc6bJ7xqSSeVAA+4UqmBuKPhzwsJkcoLGr7EQidPa5OXvu1pZ1ZA6o+1skRALr/kproslmTAJlC+fOAT1nPP7xqVp8kbiTcdboysJ3NAXN2uDKdnxp2gygse6rHNYHVWY2juZ9aQMialURZiYr/ywvfo9IpzL5w4evzSDhKGoUsJ3/Ci+hABDUR4j+uwlWD8GH1kyUTzrMmI/3Wows3HOL08aRuRycUEnCNYTBIHDMq+OMl2u5mPe8gKjs8zCxAG56Z1BUxHSa8H75bKQ+A==","SigningCertUrl":"https://sns.ap-southeast-2.amazonaws.com/SimpleNotificationService-433026a4050d206028891664da859041.pem","UnsubscribeUrl":"https://sns.ap-southeast-2.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:ap-southeast-2:979598289034:devops-r53:9a2f53dc-0e4d-4d3e-a0d2-a1c1aacff310","MessageAttributes":{}}}]}'

assumeRole: $(DOTENV_TARGET)
	docker run --rm -e "AWS_ACCOUNT_ID" -e "AWS_ROLE" amaysim/aws:1.1.3 assume-role.sh >> .env

test: $(DOTENV_TARGET) styleTest unitTest

shell: $(DOTENV_TARGET)
	docker-compose run $(USER_SETTINGS) --rm lambda-build sh

##########
# Others #
##########

# Removes the .env file before each deploy to force regeneration without cleaning the whole environment
rm_env:
	rm -f .env
.PHONY: rm_env

# Create .env based on .env.template if .env does not exist
.env:
	@echo "Create .env with .env.template"
	cp .env.template .env

# Create/Overwrite .env with $(DOTENV)
dotenv:
	@echo "Overwrite .env with $(DOTENV)"
	cp $(DOTENV) .env

$(DOTENV):
	$(info overwriting .env file with $(DOTENV))
	cp $(DOTENV) .env
.PHONY: $(DOTENV)

venv:
	python3.6 -m venv --copies venv
	sed -i '43s/.*/VIRTUAL_ENV="$$(cd "$$(dirname "$$(dirname "$${BASH_SOURCE[0]}" )")" \&\& pwd)"/' venv/bin/activate  # bin/activate hardcodes the path when you create it making it unusable outside the container, this patch makes it dynamic. Double dollar signs to escape in the Makefile.
	sed -i '1s/.*/#!\/usr\/bin\/env python/' venv/bin/pip*

_build: venv requirements.txt
	mkdir -p $(PACKAGE_DIR)
	sh -c 'source venv/bin/activate && pip install -r requirements.txt'
	cp -a venv/lib/python3.6/site-packages/. $(PACKAGE_DIR)/
	cp -a devops_eni/. $(PACKAGE_DIR)/
	@cd $(PACKAGE_DIR) && python -O -m compileall -q .  # creates .pyc files which might speed up initial loading in Lambda
	cd $(PACKAGE_DIR) && zip -rq ../package .

$(ARTIFACT_PATH): $(DOTENV_TARGET) _build

# Install node_modules for serverless plugins
_deps: node_modules.zip

node_modules.zip:
	yarn install --no-bin-links
	zip -rq node_modules.zip node_modules/

_deploy: node_modules.zip
	mkdir -p node_modules
	unzip -qo -d . node_modules.zip
	rm -fr .serverless
	sls deploy -v

_smokeTest:
	sls invoke -f handler

_logs:
	sls logs -f handler --startTime 5m -t

_remove:
	sls remove -v
	rm -fr .serverless

_clean:
	rm -fr node_modules.zip node_modules .serverless package .requirements venv/ run/ __pycache__/
.PHONY: _deploy _remove _clean
