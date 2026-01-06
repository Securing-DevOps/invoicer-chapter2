# AWS Infrastructure Update - Migration Guide

This document describes the updates made to bring the 8-year-old AWS provisioning code to modern 2026 standards.

## Summary of Changes

### 1. Database Updates (PostgreSQL)
- **Version**: Upgraded from PostgreSQL 9.6.2 (EOL November 2021) to PostgreSQL 16.4
- **Instance Type**: Changed from `db.t2.micro` to `db.t3.micro` (better performance, lower cost)
- **Storage**: Increased from 5GB to 20GB minimum (AWS best practice)
- **Security**:
  - Changed from publicly accessible to **private** (--no-publicly-accessible)
  - Enabled storage encryption at rest (--storage-encrypted)
  - Enabled SSL/TLS for connections in transit (sslmode: require)
  - Added 7-day backup retention (--backup-retention-period 7)
- **Networking**: Added DB subnet group for proper VPC integration

### 2. Elastic Beanstalk Platform Updates
- **Platform**: Updated from Amazon Linux 1 (EOL June 2020) to Amazon Linux 2023
  - Fallback to Amazon Linux 2 if AL2023 is not yet available in your region
- **Docker**: Uses latest Docker solution stack for the selected platform

### 3. Networking & Security Improvements
- **DB Subnet Group**: Properly created to span multiple availability zones
- **Security Groups**:
  - Better naming convention: `<identifier>-db` instead of just `<identifier>`
  - Added resource tags for better tracking (Name, Environment, Owner, ManagedBy)
  - Maintains proper isolation between EB instances and RDS

### 4. CI/CD Pipeline Updates
- **CircleCI**: Updated to version 2.1
- **Go Version**: Updated from Go 1.10 (2018) to Go 1.21
- **Base Image**: Changed from `circleci/golang:1.10` to `cimg/go:1.21`

### 5. New Infrastructure Management Features
- **Cleanup Script**: Added `destroy_ebs_env.sh` for proper resource teardown
- **Better Tagging**: All resources properly tagged with Owner and Environment information
- **Error Handling**: Improved error messages and confirmation prompts

## Breaking Changes

### SSL/TLS Requirement
The PostgreSQL connection now **requires SSL/TLS** encryption. If your application doesn't support SSL connections, you'll need to:
1. Update your PostgreSQL driver to support SSL
2. Ensure your application can verify SSL certificates
3. Or temporarily set `INVOICER_POSTGRES_SSLMODE` back to `disable` (not recommended for production)

### Private Database
The RDS instance is no longer publicly accessible. This means:
- You cannot connect directly from your local machine without a VPN or bastion host
- Only EC2 instances in the same VPC with the proper security group can connect
- This is a **security best practice** for production environments

### Instance Type Change
The new `db.t3.micro` instance type:
- May have slightly different pricing than `db.t2.micro`
- Offers better performance and newer CPU architecture
- Is the current-generation instance type (t2 is previous-generation)

## Prerequisites

Before running the updated scripts, ensure you have:

1. **AWS CLI v2** installed and configured
   ```bash
   aws --version  # Should be 2.x or higher
   aws configure  # Set up credentials if needed
   ```

2. **jq** JSON processor installed
   ```bash
   # macOS
   brew install jq

   # Ubuntu/Debian
   sudo apt-get install jq

   # Amazon Linux
   sudo yum install jq
   ```

3. **AWS Credentials** with appropriate permissions:
   - EC2: Create/describe VPCs, subnets, security groups
   - RDS: Create/delete database instances, subnet groups
   - Elastic Beanstalk: Create/delete applications and environments
   - S3: Create/delete buckets
   - IAM: Service roles for Elastic Beanstalk (auto-created)

## Usage

### Creating Infrastructure

```bash
./create_ebs_env.sh
```

The script will:
1. Create a unique identifier based on your username and timestamp
2. Set up networking (VPC, subnets, security groups)
3. Create a PostgreSQL 16.4 RDS instance (takes ~5-10 minutes)
4. Create an Elastic Beanstalk application and environment
5. Deploy the Docker container
6. Output the public URL and connection details

**Example output:**
```
Creating EBS application ulfrivcr202601061530
default vpc is vpc-abc123
subnets: subnet-123 subnet-456 subnet-789
DB subnet group created
DB security group is sg-xyz789
RDS Postgres database is being created. username=invoicer; password='...'
...
Environment is being deployed. Public endpoint is http://ulfrivcr202601061530-invoicer-api.us-east-1.elasticbeanstalk.com
```

**Important**: Save the generated password from the output! It's stored in `tmp/<identifier>/rds.json` as well.

### Destroying Infrastructure

```bash
./destroy_ebs_env.sh <identifier>
```

Example:
```bash
./destroy_ebs_env.sh ulfrivcr202601061530
```

The cleanup script will:
1. Show you what will be deleted
2. Ask for confirmation (type `yes` to proceed)
3. Terminate the Elastic Beanstalk environment
4. Delete the EB application
5. Delete the RDS database instance (no final snapshot)
6. Remove the DB subnet group
7. Delete security groups
8. Empty and delete the S3 bucket
9. Clean up local tmp directory

**To list available environments:**
```bash
./destroy_ebs_env.sh
# This will show available identifiers from tmp/ directory
```

## Region Configuration

By default, resources are created in `us-east-1`. To use a different region:

```bash
export AWS_REGION=us-west-2
./create_ebs_env.sh
```

## Cost Considerations

Estimated monthly costs for the infrastructure (as of 2026):

- **RDS db.t3.micro**: ~$15-20/month (with 20GB storage)
- **Elastic Beanstalk**: Free (you only pay for underlying EC2)
- **EC2 t2.micro**: ~$8-10/month (EB default)
- **Data Transfer**: Variable
- **S3 Storage**: < $1/month (minimal usage)

**Total**: Approximately $25-35/month

**Cost Optimization Tips:**
- Stop the RDS instance when not in use (can save ~70% of DB costs)
- Use db.t4g.micro (ARM-based) for additional savings
- Delete resources promptly using the cleanup script

## Troubleshooting

### Issue: "PostgreSQL version 16.4 is not available"

**Solution**: Check available versions:
```bash
aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion'
```

Update line 58 in `create_ebs_env.sh` with an available version (16.x family).

### Issue: "Security group still has dependencies"

**Cause**: Security groups can't be deleted while EC2 instances are using them.

**Solution**: Wait longer for EB environment termination, or manually remove instances:
```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=*<identifier>*"
```

### Issue: "SSL connection failed"

**Cause**: Application doesn't support PostgreSQL SSL connections.

**Quick Fix**: Temporarily disable SSL (not recommended for production):
```json
// In ebs-options.json, change:
"Value": "require"
// to:
"Value": "disable"
```

**Proper Fix**: Update your PostgreSQL driver and application code to support SSL.

### Issue: "Cannot connect to RDS from local machine"

**Cause**: RDS is now private and not publicly accessible.

**Solutions**:
1. Use AWS Systems Manager Session Manager to access EB instances
2. Set up a bastion host in the VPC
3. Use AWS VPN or Direct Connect
4. For testing only, temporarily make RDS public:
   ```bash
   aws rds modify-db-instance \
       --db-instance-identifier <identifier> \
       --publicly-accessible
   ```

## Migration from Old Infrastructure

If you have existing infrastructure from the old scripts:

1. **Export data** from old PostgreSQL 9.6 database
2. **Run cleanup** on old environment (if old cleanup script exists)
3. **Create new infrastructure** with updated scripts
4. **Restore data** to new PostgreSQL 16.4 database
5. **Update application** configuration if needed

### Database Migration Example

```bash
# From old DB (if publicly accessible)
pg_dump -h <old-host> -U invoicer -d invoicer -F c -f invoicer_backup.dump

# To new DB (from EB instance or bastion)
pg_restore -h <new-host> -U invoicer -d invoicer -v invoicer_backup.dump
```

## Security Best Practices Implemented

- ✅ Database encryption at rest
- ✅ SSL/TLS encryption in transit
- ✅ Private database (not publicly accessible)
- ✅ Security groups with least privilege
- ✅ Automated backups (7-day retention)
- ✅ Resource tagging for governance
- ✅ Modern, supported software versions

## Future Improvements to Consider

While this update brings the infrastructure to 2026 standards, consider these additional improvements:

1. **Infrastructure as Code**: Migrate to Terraform or AWS CloudFormation for better state management
2. **Multi-AZ**: Enable multi-AZ for RDS for high availability
3. **Secrets Manager**: Store database passwords in AWS Secrets Manager instead of environment variables
4. **Container Registry**: Use Amazon ECR instead of Docker Hub
5. **Monitoring**: Add CloudWatch alarms for RDS and EB health
6. **Auto Scaling**: Configure EB auto-scaling policies
7. **CDN**: Add CloudFront for static asset delivery
8. **WAF**: Add AWS WAF for application-layer protection
9. **VPC Design**: Use separate public/private subnets with NAT Gateway
10. **CI/CD**: Consider migrating to GitHub Actions or AWS CodePipeline

## Support

For issues with:
- **AWS Services**: Check AWS documentation or AWS Support
- **This Infrastructure Code**: Review this document or create an issue in the repository
- **Application Code**: Refer to the main project documentation

## References

- [Amazon RDS PostgreSQL Release Notes](https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/)
- [Amazon Linux 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/)
- [AWS Elastic Beanstalk Platforms](https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/)
- [PostgreSQL 16 Release Notes](https://www.postgresql.org/docs/16/release-16.html)
