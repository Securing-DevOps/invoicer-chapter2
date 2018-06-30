#!/usr/bin/env bash

# requires: pip install awscli awsebcli

# uncomment to debug
#set -x

# Don't set this variable if you are copy/pasting or vim-sliming
EXEC_AS_SCRIPT=true

PS1="#> " 

fail() {
    echo configuration failed
    if [ $EXEC_AS_SCRIPT ] ; 
      then exit 1; 
      else echo "failed in terminal";
    fi
}


export AWS_DEFAULT_REGION=${AWS_REGION:-us-west-2}

datetag=$(date +%Y%m%d%H%M)
identifier=$(whoami)-invoicer-$datetag
mkdir -p tmp/$identifier


exit

# Notes. We left off with this.
#identifier=psgivens-invoicer-201806120644
#datetag="201806120644"

# The latest events can be found at 
#cat tmp/$identifier/eb-events*.json |less



#aws elasticbeanstalk describe-events --environment-id $apieid > tmp/$identifier/eb-events.json
#aws elasticbeanstalk describe-events --environment-id $apieid > tmp/$identifier/eb-events1.json


# After the error message, a web-page was being displayed. Then I restarted the webservers
# and now I am getting a 502 Bad Gateway. 
#
# https://aws.amazon.com/premiumsupport/knowledge-center/load-balancer-http-502-errors/
#
# Things to try:
# 1) Look for more logging information through the console/cli.
# 2) Log into the VMs and look at the logs locally.
# 3) Try running the docker container locally against a postgresql database. 






clear
echo "Creating EBS application $identifier"
# Find the ID of the default VPC
aws ec2 describe-vpcs --filters Name=isDefault,Values=true > tmp/$identifier/defaultvpc.json || fail
vpcid=$(jq -r '.Vpcs[0].VpcId' tmp/$identifier/defaultvpc.json)
echo "default vpc is $vpcid"

# Create a security group for the database
aws ec2 create-security-group \
    --group-name $identifier \
    --description "access control to Invoicer Postgres DB" \
    --vpc-id $vpcid > tmp/$identifier/dbsg.json || fail
dbsg=$(jq -r '.GroupId' tmp/$identifier/dbsg.json)
echo "DB security group is $dbsg"

# Create the database
dbinstclass="db.t2.micro"
dbstorage=5
dbpass=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null| tr -dc _A-Z-a-z-0-9)
aws rds create-db-instance \
    --db-name invoicer \
    --db-instance-identifier "$identifier" \
    --vpc-security-group-ids "$dbsg" \
    --allocated-storage "$dbstorage" \
    --db-instance-class "$dbinstclass" \
    --engine postgres \
    --engine-version 9.6.2 \
    --auto-minor-version-upgrade \
    --publicly-accessible \
    --master-username invoicer \
    --master-user-password "$dbpass" \
    --no-multi-az > tmp/$identifier/rds.json || fail
echo "RDS Postgres database is being created. username=invoicer; password='$dbpass'"

# Retrieve the database hostname
while true;
do
    echo "aws rds describe-db-instances --db-instance-identifier $identifier"
    aws rds describe-db-instances --db-instance-identifier $identifier > tmp/$identifier/rds.json
    clear
    echo "aws rds describe-db-instances --db-instance-identifier $identifier"
    cat tmp/$identifier/rds.json
    dbhost=$(jq -r '.DBInstances[0].Endpoint.Address' tmp/$identifier/rds.json)
    dbstatus=$(jq -r '.DBInstances[0].DBInstanceStatus' tmp/$identifier/rds.json)
    echo "Database status: $dbstatus"
    date
    if [[ "$dbhost" != "null" && "$dbstatus" == "available" ]]; then break; fi
    #if [ "$dbstatus" != "deleting" ]; then break; fi
    echo -n '.'
    sleep 10
done
echo "dbhost=$dbhost"

# tagging rds instance
aws rds add-tags-to-resource \
    --resource-name $(jq -r '.DBInstances[0].DBInstanceArn' tmp/$identifier/rds.json) \
    --tags "Key=environment-name,Value=invoicer-api"
aws rds add-tags-to-resource \
    --resource-name $(jq -r '.DBInstances[0].DBInstanceArn' tmp/$identifier/rds.json) \
    --tags "Key=Owner,Value=$(whoami)"

# Create an elasticbeantalk application
aws elasticbeanstalk create-application \
    --application-name $identifier \
    --description "Invoicer $env $datetag" > tmp/$identifier/ebcreateapp.json || fail
echo "ElasticBeanTalk application created"

#aws elasticbeanstalk list-available-solution-stacks  |less

#"$(aws elasticbeanstalk list-available-solution-stacks | \
    #jq -r '.SolutionStacks[]' | grep -P '.+Amazon Linux.+Docker.+' )"

# Get the name of the latest Docker solution stack
dockerstack="$(aws elasticbeanstalk list-available-solution-stacks | \
    jq -r '.SolutionStacks[]' | grep -P '.+Amazon Linux.+Docker.+' | head -1)"
echo "dockerstack is '$dockerstack'"

# Create the EB API environment
sed "s/POSTGRESPASSREPLACEME/$dbpass/" ebs-options.json > tmp/$identifier/ebs-options.json || fail
sed -i "s/POSTGRESHOSTREPLACEME/$dbhost/" tmp/$identifier/ebs-options.json || fail
cat tmp/$identifier/ebs-options.json 

aws elasticbeanstalk create-environment \
    --application-name $identifier \
    --environment-name $identifier-inv-api \
    --description "Invoicer API environment" \
    --tags "Key=Owner,Value=$(whoami)" \
    --solution-stack-name "$dockerstack" \
    --option-settings file://tmp/$identifier/ebs-options.json \
    --tier "Name=WebServer,Type=Standard,Version=''" > tmp/$identifier/ebcreateapienv.json || fail
apieid=$(jq -r '.EnvironmentId' tmp/$identifier/ebcreateapienv.json)
echo "API environment $apieid is being created"


# grab the instance ID of the API environment, then its security group, and add that to the RDS security group
while true;
do
    aws elasticbeanstalk describe-environment-resources --environment-id $apieid > tmp/$identifier/ebapidesc.json || fail
    clear
    echo "aws elasticbeanstalk describe-environment-resources --environment-id $apieid"
    cat tmp/$identifier/ebapidesc.json
    ec2id=$(jq -r '.EnvironmentResources.Instances[0].Id' tmp/$identifier/ebapidesc.json)
    date
    echo "ec2id is $ec2id"
    if [ "$ec2id" != "null" ]; then break; fi
    echo -n '.'
    sleep 10
done
echo
aws ec2 describe-instances --instance-ids $ec2id > tmp/$identifier/${ec2id}.json || fail
sgid=$(jq -r '.Reservations[0].Instances[0].SecurityGroups[0].GroupId' tmp/$identifier/${ec2id}.json)
aws ec2 authorize-security-group-ingress --group-id $dbsg --source-group $sgid --protocol tcp --port 5432 || fail
echo "API security group $sgid authorized to connect to database security group $dbsg"

# Upload the application version
aws s3 mb s3://$identifier
aws s3 cp app-version.json s3://$identifier/

aws elasticbeanstalk create-application-version \
    --application-name "$identifier" \
    --version-label invoicer-api \
    --source-bundle "S3Bucket=$identifier,S3Key=app-version.json" > tmp/$identifier/app-version-s3.json

# Wait for the environment to be ready (green)
echo -n "waiting for environment"
while true; do
    aws elasticbeanstalk describe-environments --environment-id $apieid > tmp/$identifier/$apieid.json
    clear
    echo "aws elasticbeanstalk describe-environments --environment-id $apieid"
    cat tmp/$identifier/$apieid.json
    health="$(jq -r '.Environments[0].Health' tmp/$identifier/$apieid.json)"
    date
    echo "Health is $health"
    if [ "$health" == "Green" ]; then break; fi
    echo -n '.'
    sleep 10
done
echo

# Deploy the docker container to the instances
aws elasticbeanstalk update-environment \
    --application-name $identifier \
    --environment-id $apieid \
    --version-label invoicer-api > tmp/$identifier/$apieid.json



url="$(jq -r '.CNAME' tmp/$identifier/$apieid.json)"
echo "Environment is being deployed. Public endpoint is http://$url"

echo $url


# Post the example
curl -X POST \
    --data '{"is_paid": false, "amount": 1664, "due_date": "2016-05-07T23:00:00Z", "charges": [ { "type":"blood work", "amount": 1664, "description": "blood work" } ] }' \
    http://$url/invoice

curl http://$url/invoice/1

echo $url


# Should be something like: 
{"ID":1,"CreatedAt":"2016-05-21T15:33:21.855874Z","UpdatedAt":"2016-05-21T15:33:21.855874Z","DeletedAt":null,"is_paid":false,"amount":1664,"payment_date":"0001-01-01T00:00:00Z","due_date":"2016-05-07T23:00:00Z","charges":[{"ID":1,"CreatedAt":"2016-05-21T15:33:21.8637Z","UpdatedAt":"2016-05-21T15:33:21.8637Z","DeletedAt":null,"invoice_id":1,"type":"blood
work","amount":1664,"description":"blood work"}]}
















