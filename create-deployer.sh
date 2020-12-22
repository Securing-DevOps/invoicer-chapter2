aws elasticbeanstalk create-application \
    --application-name deployer \
    --description "deployer"
	
aws elasticbeanstalk create-environment \
    --application-name deployer \
    --environment-name deployer-api \
    --description "deployer API environment" \
    --tags "Key=Owner,Value=$(whoami)" \
    --option-settings file://ebs-options-deployer.json \
    --solution-stack-name "64bit Amazon Linux 2018.03 v2.16.2 running Docker 19.03.13-ce" \
    --tier "Name=WebServer,Type=Standard,Version=''"
	
aws s3 mb s3://deployer-mathdube
aws s3 cp app-version-deployer.json s3://deployer-mathdube/

aws elasticbeanstalk create-application-version \
    --application-name "deployer" \
    --version-label deployer-api \
    --source-bundle "S3Bucket=deployer-mathdube,S3Key=app-version-deployer.json"

aws elasticbeanstalk update-environment \
    --application-name deployer \
    --environment-name deployer-api \
    --version-label deployer-api