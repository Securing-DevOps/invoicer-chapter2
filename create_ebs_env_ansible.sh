#!/usr/bin/env bash

# requires: pip install awscli awsebcli

# uncomment to debug
#set -x


export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-1}

datetag=$(date +%Y%m%d%H%M)
identifier=invoicer
mkdir -p tmp/$identifier


# Create an elasticbeantalk application
aws elasticbeanstalk create-application \
    --application-name invoicer \
    --description "invoicer" 

aws elasticbeanstalk create-environment \
    --application-name invoicer \
    --environment-name invoicer-api \
    --description "Invoicer API environment" \
    --tags "Key=Owner,Value=$(whoami)" \
    --solution-stack-name "64bit Amazon Linux 2018.03 v2.16.2 running Docker 19.03.13-ce" \
    --option-settings file:///tmp/ebs-options.json \
    --tier "Name=WebServer,Type=Standard,Version=''"


aws ec2 describe-instances --instance-ids $ec2id 
aws ec2 authorize-security-group-ingress --group-id $dbsg --source-group $sgid --protocol tcp --port 5432 || fail

aws ec2 authorize-security-group-ingress --group-id sg-0a68a5e43f021cf2e --source-group sg-045cdeee7a8721e9d --protocol tcp --port 5432 || fail


aws elasticbeanstalk create-application-version \
    --application-name "invoicer" \
    --version-label invoicer-api \
    --source-bundle "S3Bucket=invoicer-mathdube,S3Key=app-version.json"

# Deploy the docker container to the instances
aws elasticbeanstalk update-environment \
    --application-name invoicer \
    --environment-name invoicer-api \
    --version-label invoicer-api 
