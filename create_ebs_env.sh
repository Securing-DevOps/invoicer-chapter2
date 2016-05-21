#!/usr/bin/env bash

# requires: pip install awscli awsebcli

# uncomment to debug
#set -x

fail() {
    echo configuration failed
    exit 1
}

export AWS_DEFAULT_REGION=us-east-1

datetag=$(date +%Y%m%d%H%M)
identifier=invoicer$datetag
mkdir -p tmp/$identifier

echo "Creating stack $identifier"

# Find the ID of the default VPC
aws ec2 describe-vpcs --filters Name=isDefault,Values=true > tmp/$identifier/defaultvpc.json || fail
vpcid=$(grep -Poi '"vpcid": "(.+)"' tmp/$identifier/defaultvpc.json|cut -d '"' -f 4)
echo "default vpc is $vpcid"

# Create a security group for the database
aws ec2 create-security-group \
    --group-name $identifier \
    --description "access control to Invoicer Postgres DB" \
    --vpc-id $vpcid > tmp/$identifier/dbsg.json || fail
dbsg=$(grep -Poi '"groupid": "(.+)"' tmp/$identifier/dbsg.json|cut -d '"' -f 4)
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
    --engine-version 9.4.5 \
    --auto-minor-version-upgrade \
    --publicly-accessible \
    --master-username invoicer \
    --master-user-password "$dbpass" \
    --no-multi-az > tmp/$identifier/rds.json || fail
echo "RDS Postgres database created. username=invoicer; password='$dbpass'"

# Retrieve the database hostname
while true;
do
    dbhost=$(aws rds describe-db-instances --db-instance-identifier $identifier |grep -A 2 -i endpoint|grep -Poi '"Address": "(.+)"'|cut -d '"' -f 4)
    if [ ! -z $dbhost ]; then break; fi
    echo "database is not ready yet. waiting"
    sleep 10
done

# Create an elasticbeantalk application
aws elasticbeanstalk create-application \
    --application-name $identifier \
    --description "Invoicer $env $datetag" > tmp/$identifier/ebcreateapp.json || fail
echo "ElasticBeanTalk application created"

# Get the name of the latest Docker solution stack
dockerstack="$(aws elasticbeanstalk list-available-solution-stacks | \
    grep -P '"SolutionStackName": ".+Amazon Linux.+Docker.+"' | \
    grep -v "Multi-container" | cut -d ':' -f 2 | \
    sed 's/"//g' | sed 's/^ //' | sort |tail -1)"

# Create the EB API environment
sed "s/POSTGRESPASSREPLACEME/$dbpass/" ebs-options.json > tmp/$identifier/ebs-options.json || fail
sed -i "s/POSTGRESHOSTREPLACEME/$dbhost/" tmp/$identifier/ebs-options.json || fail
aws elasticbeanstalk create-environment \
    --application-name $identifier \
    --environment-name api$env$datetag \
    --description "Invoicer environment" \
    --tags "Key=Owner,Value=$(whoami)" \
    --solution-stack-name "$dockerstack" \
    --option-settings file://tmp/$identifier/ebs-options.json \
    --tier "Name=WebServer,Type=Standard,Version=''" > tmp/$identifier/ebcreateapienv.json || fail
apieid=$(grep -Pi '"EnvironmentId": "(.+)"' tmp/$identifier/ebcreateapienv.json |cut -d '"' -f 4)
echo "API environment $apieid created"

# grab the instance ID of the API environment, then its security group, and add that to the RDS security group
while true;
do
    aws elasticbeanstalk describe-environment-resources --environment-id $apieid > tmp/$identifier/ebapidesc.json || fail
    ec2id=$(grep -A 3 -i instances tmp/$identifier/ebapidesc.json | grep -Pi '"id": "(.+)"'|cut -d '"' -f 4)
    if [ ! -z $ec2id ]; then break; fi
    echo "stack is not ready yet. waiting"
    sleep 10
done
aws ec2 describe-instances --instance-ids $ec2id > tmp/$identifier/${ec2id}.json || fail
sgid=$(grep -A 4 -i SecurityGroups tmp/$identifier/${ec2id}.json | grep -Pi '"GroupId": "(.+)"' | cut -d '"' -f 4)
aws ec2 authorize-security-group-ingress --group-id $dbsg --source-group $sgid --protocol tcp --port 5432 || fail
echo "API security group $sgid authorized to connect to database security group $dbsg"

# Upload the application version
aws s3 mb s3://$identifier
aws s3 cp ebs.json s3://$identifier/
aws elasticbeanstalk create-application-version \
    --application-name "$identifier" \
    --version-label invoicer-api \
    --source-bundle "S3Bucket=$identifier,S3Key=ebs.json"

aws elasticbeanstalk update-environment \
    --application-name $identifier \
    --environment-id $apieid \
    --version-label invoicer-api

echo "Environment ready. Create the application versions in the elasticbeanstalk web console and deploy your container."
