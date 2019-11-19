Securing DevOps's invoicer
==========================

A simple REST API that manages invoices.

This is the code for Chapter 2 of Securing DevOps. It only contains the code and
scripts relevant to the basic setup of the invoicer application and
infrastructure.

The master branch is kept at https://securing-devops.com/invoicer but if you are
interested in chapter-specific versions of the invoicer.

Get your own copy
-----------------

To try out the code in this repository, first create a fork in your own github
account. Now before you do anything, edit the file in `.circleci/config.yml` and
replace the `working_directory` parameter with your own namespace.

For example:
```yaml
    working_directory: /go/src/github.com/Securing-DevOps/invoicer-chapter2
```
would become:
```yaml
    working_directory: /go/src/github.com/jvehent/invoicer-chapter2
```

Then, sign up for circleci and build the project.The build will initially fail
because it lacks the Docker credentials to push the invoicer's image to
dockerhub.

Head over to hub.docker.com, create an account, then create a repository to store
the docker containers into, as explained in chapter 2.

Head back to CircleCi and in the "Project Setting", add the following
"Environment Variables" with the appropriate values.

- DOCKER_USER
- DOCKER_PASS

These variable will allow CircleCI to upload the docker container of the
invoicer into your own account. Once added, trigger a rebuild of the CircleCI
job and it should succeed and upload the container without issue.

You can then pull and run the container from your repository and run it locally.  The `-it` flag keeps the log for the container open in the terminal window.  The `-p 8080:8080` flag connects the host port 8080 to the container port 8080.  Note in the `main.go` file on line 81 that the go microservice calls `ListenAndServe` on port 8080.

```bash
$ docker run -it -p 8080:8080 <MyDockerHubUsername>/invoicer
```

Once the container is running open another terminal window and test that the heartbeat is returned from the application by calling the heartbeat API endpoint.

```
curl localhost:8080/__heartbeat__
```

Now you know the container will properly build and that the invoicer is ready to work.  So let's move to deploying it into the cloud.

Build the AWS infrastructure
----------------------------

The script `create_ebs_env.sh` creates a complete AWS infrastructure ready to
host the invoicer. The script first creates a database, then an elastic
beanstalk environment, and finally deploys the docker container of the
invoicer. All you need to get started is creating an AWS account, then
create a local profile (see chapter 2 for details) and run the following:

```bash
$ export AWS_PROFILE=cloudservices-aws-dev

$ export AWS_REGION=eu-west-1

$ ./create_ebs_env.sh
```

The script will outputs resources name and credentials for the new environment.
```
Creating EBS application ulfr-invoicer-201709231530
default vpc is vpc-c02b81a5
DB security group is sg-fc20478f
RDS Postgres database is being created. username=invoicer; password='i0l2jSQ5WkK_441c8dXwlYods9'
..................dbhost=ulfr-invoicer-201709231530.czvvrkdqhklf.us-east-1.rds.amazonaws.com
ElasticBeanTalk application created
API environment e-qp2pyjhhma is being created
.....
API security group sg-732d4a00 authorized to connect to database security group sg-fc20478f
make_bucket: ulfr-invoicer-201709231530
upload: ./app-version.json to s3://ulfr-invoicer-201709231530/app-version.json
waiting for environment....................
Environment is being deployed. Public endpoint is http://ulfr-invoicer-201709231530-invoicer-api.egmh2pupxy.us-east-1.elasticbeanstalk.com
```

Build the AWS infrastructure
----------------------------

The script `create_ebs_env.sh` creates a complete AWS infrastructure ready to
host the invoicer. The script first creates a database, then an elastic
beanstalk environment, and finally deploys the docker container of
invoicer-chapter2. All you need to get started is creating an AWS account, then
create a local profile (see chapter 2 for details) and run the following:

```bash
$ export AWS_PROFILE=cloudservices-aws-dev

$ export AWS_REGION=eu-west-1

$ ./create_ebs_env.sh
```

The script will outputs resources name and credentials for the new environment.
```
Creating EBS application ulfr-invoicer-201709231530
default vpc is vpc-c02b81a5
DB security group is sg-fc20478f
RDS Postgres database is being created. username=invoicer; password='i0l2jSQ5WkK_441c8dXwlYods9'
..................dbhost=ulfr-invoicer-201709231530.czvvrkdqhklf.us-east-1.rds.amazonaws.com
ElasticBeanTalk application created
API environment e-qp2pyjhhma is being created
.....
API security group sg-732d4a00 authorized to connect to database security group sg-fc20478f
make_bucket: ulfr-invoicer-201709231530
upload: ./app-version.json to s3://ulfr-invoicer-201709231530/app-version.json
waiting for environment....................
Environment is being deployed. Public endpoint is http://ulfr-invoicer-201709231530-invoicer-api.egmh2pupxy.us-east-1.elasticbeanstalk.com
```

Manual build
------------

Build a statically linked invoicer binary. Requires Go 1.6.

```bash
$ mkdir bin
$ go build --ldflags '-extldflags "-static"' -o bin/invoicer .
```

Then build the container.
```bash
$ docker build -t securingdevops/invoicer .
```

Database Configuration
----------------------

The invoicer will automatically create a local sqlite database by default, but
if you want to run with postgres, follow these instructions.

Create a postgres database named `invoicer` and grant user `invoicer` full
access to it.
```sql
CREATE DATABASE invoicer;
CREATE ROLE invoicer;
ALTER ROLE invoicer WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN PASSWORD 'invoicer';
ALTER DATABASE invoicer OWNER TO invoicer;
```

When running PG and Docker on the same box, configure `pg_hba` to allow the
local docker network to connect.
```bash
...
# trust local docker hosts
host    all             all             172.17.0.0/16           trust
```

Run
---

```bash
$ docker run -it \
    -e INVOICER_USE_POSTGRES="yes" \
    -e INVOICER_POSTGRES_USER="invoicer" \
    -e INVOICER_POSTGRES_PASSWORD="invoicer" \
    -e INVOICER_POSTGRES_HOST="172.17.0.1" \
    -e INVOICER_POSTGRES_DB="invoicer" \
    -e INVOICER_POSTGRES_SSLMODE="disable" \
    securingdevops/invoicer-chapter2
```

Use
---
Create an invoice
```bash
$ curl -X POST \
--data '{"is_paid": false, "amount": 1664, "due_date": "2016-05-07T23:00:00Z", "charges": [ { "type":"blood work", "amount": 1664, "description": "blood work" } ] }' \
http://172.17.0.2:8080/invoice
```

Retrieve an invoice
```bash
$ curl http://172.17.0.2:8080/invoice/1
{"ID":1,"CreatedAt":"2016-05-21T15:33:21.855874Z","UpdatedAt":"2016-05-21T15:33:21.855874Z","DeletedAt":null,"is_paid":false,"amount":1664,"payment_date":"0001-01-01T00:00:00Z","due_date":"2016-05-07T23:00:00Z","charges":[{"ID":1,"CreatedAt":"2016-05-21T15:33:21.8637Z","UpdatedAt":"2016-05-21T15:33:21.8637Z","DeletedAt":null,"invoice_id":1,"type":"blood
work","amount":1664,"description":"blood work"}]}
```
