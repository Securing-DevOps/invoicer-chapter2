#!/usr/bin/env bash

# requires: pip install awscli awsebcli

# uncomment to debug
#set -x

fail() {
    echo configuration failed
    exit 1
}

export AWS_DEFAULT_REGION=${AWS_REGION:-eu-west-2}

datetag=$(date +%Y%m%d%H%M)
identifier=$(whoami)ivcr$datetag
mkdir -p tmp/$identifier

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
dbinstclass="db.t3.micro"
dbstorage=5
dbpass=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null| tr -dc _A-Z-a-z-0-9)
echo "Password is $dbpass eom"
aws rds create-db-instance \
    --db-name invoicer \
    --db-instance-identifier "$identifier" \
    --vpc-security-group-ids "$dbsg" \
    --allocated-storage "$dbstorage" \
    --db-instance-class "$dbinstclass" \
    --engine postgres \
    --auto-minor-version-upgrade \
    --publicly-accessible \
    --master-username invoicer \
    --master-user-password "$dbpass" \
    --no-multi-az > tmp/$identifier/rds.json || fail
echo "RDS Postgres database is being created. username=invoicer; password='$dbpass'"

# Retrieve the database hostname
while true;
do
    aws rds describe-db-instances --db-instance-identifier $identifier > tmp/$identifier/rds.json
    dbhost=$(jq -r '.DBInstances[0].Endpoint.Address' tmp/$identifier/rds.json)
    if [ "$dbhost" != "null" ]; then break; fi
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

# Get the name of the latest Docker solution stack
dockerstack="$(aws elasticbeanstalk list-available-solution-stacks | \
    jq -r '.SolutionStacks[]' | grep -P '.+Amazon Linux.+running Docker' | head -1)"

# Create the EB API environment
sed "s/POSTGRESPASSREPLACEME/$dbpass/" ebs-options.json > tmp/$identifier/ebs-options.json || fail
sed -i "s/POSTGRESHOSTREPLACEME/$dbhost/" tmp/$identifier/ebs-options.json || fail
aws elasticbeanstalk create-environment \
    --application-name $identifier \
    --environment-name $identifier-invoicer-api \
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
    ec2id=$(jq -r '.EnvironmentResources.Instances[0].Id' tmp/$identifier/ebapidesc.json)
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
    health="$(jq -r '.Environments[0].Health' tmp/$identifier/$apieid.json)"
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
