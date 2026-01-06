#!/usr/bin/env bash

# This script destroys the AWS infrastructure created by create_ebs_env.sh
# Usage: ./destroy_ebs_env.sh <identifier>
# Example: ./destroy_ebs_env.sh ulfrivcr202601061530

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <identifier>"
    echo "Example: $0 ulfrivcr202601061530"
    echo ""
    echo "Available environments:"
    ls -d tmp/*/ 2>/dev/null | sed 's|tmp/||' | sed 's|/||' || echo "No environments found in tmp/"
    exit 1
fi

identifier=$1
export AWS_DEFAULT_REGION=${AWS_REGION:-us-east-1}

echo "WARNING: This will delete the following resources for identifier: $identifier"
echo "  - Elastic Beanstalk Environment: $identifier-invoicer-api"
echo "  - Elastic Beanstalk Application: $identifier"
echo "  - RDS Database Instance: $identifier"
echo "  - DB Subnet Group: $identifier-db-subnet"
echo "  - Security Group: $identifier-db"
echo "  - S3 Bucket: s3://$identifier"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

fail() {
    echo "Error: $1"
    exit 1
}

echo "Starting cleanup for $identifier..."

# Get the API environment ID if it exists
if [ -f "tmp/$identifier/ebcreateapienv.json" ]; then
    apieid=$(jq -r '.EnvironmentId' tmp/$identifier/ebcreateapienv.json)
    echo "Found API Environment ID: $apieid"

    # Terminate the Elastic Beanstalk environment
    echo "Terminating Elastic Beanstalk environment..."
    aws elasticbeanstalk terminate-environment \
        --environment-id "$apieid" 2>/dev/null || echo "Environment already terminated or not found"

    # Wait for environment to terminate
    echo -n "Waiting for environment to terminate"
    while true; do
        status=$(aws elasticbeanstalk describe-environments \
            --environment-ids "$apieid" 2>/dev/null | \
            jq -r '.Environments[0].Status // "Terminated"')
        if [ "$status" == "Terminated" ] || [ "$status" == "null" ]; then
            break
        fi
        echo -n '.'
        sleep 10
    done
    echo " done"
fi

# Delete the Elastic Beanstalk application
echo "Deleting Elastic Beanstalk application..."
aws elasticbeanstalk delete-application \
    --application-name "$identifier" \
    --terminate-env-by-force 2>/dev/null || echo "Application already deleted or not found"

# Delete RDS instance
echo "Deleting RDS database instance..."
aws rds delete-db-instance \
    --db-instance-identifier "$identifier" \
    --skip-final-snapshot \
    --delete-automated-backups 2>/dev/null || echo "RDS instance already deleted or not found"

# Wait for RDS to delete
echo -n "Waiting for RDS instance to delete"
while true; do
    status=$(aws rds describe-db-instances \
        --db-instance-identifier "$identifier" 2>/dev/null | \
        jq -r '.DBInstances[0].DBInstanceStatus // "deleted"')
    if [ "$status" == "deleted" ] || [ "$status" == "null" ]; then
        break
    fi
    echo -n '.'
    sleep 10
done
echo " done"

# Delete DB subnet group
echo "Deleting DB subnet group..."
aws rds delete-db-subnet-group \
    --db-subnet-group-name "$identifier-db-subnet" 2>/dev/null || echo "DB subnet group already deleted or not found"

# Get security group ID and delete it
if [ -f "tmp/$identifier/dbsg.json" ]; then
    dbsg=$(jq -r '.GroupId' tmp/$identifier/dbsg.json)
    echo "Deleting security group $dbsg..."
    aws ec2 delete-security-group \
        --group-id "$dbsg" 2>/dev/null || echo "Security group already deleted or not found"
else
    # Try to find by name (try both old and new naming conventions)
    echo "Attempting to delete security group by name..."
    aws ec2 delete-security-group \
        --group-name "$identifier-db" 2>/dev/null || \
    aws ec2 delete-security-group \
        --group-name "$identifier" 2>/dev/null || echo "Security group not found by name"
fi

# Empty and delete S3 bucket
echo "Emptying and deleting S3 bucket..."
aws s3 rb "s3://$identifier" --force 2>/dev/null || echo "S3 bucket already deleted or not found"

# Remove local tmp directory
echo "Removing local tmp directory..."
rm -rf "tmp/$identifier"

echo ""
echo "Cleanup complete for $identifier!"
echo "All resources have been deleted."
