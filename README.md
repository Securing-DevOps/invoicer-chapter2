Securing DevOps's invoicer
==========================

A simple REST API that manages invoices.

The master branch is kept at https://securing-devops.com/invoicer but if you are
interested in chapter-specific versions of the invoicer, you may want to check out:

- Chapter 2: https://securing-devops.com/ch02/invoicer
- Chapter 3: https://securing-devops.com/ch03/invoicer

To pull the live container of the master branch, use `docker pull securingdevops/invoicer`.

Get your own copy
-----------------

To try out the code in this repository, first create a fork in your own github
account, then sign up for circleci and build the project.

The build will initially fail because it lacks the Docker credentials to push
the invoicer's image to dockerhub.

Head over to hub.docker.com, create an account, then create a repository to store
the docker containers into.

Head back to CircleCi and in the "Project Setting", add the following
"Environment Variables" with the appropriate values.

- DOCKER_EMAIL
- DOCKER_USER
- DOCKER_PASS

These variable will allow CircleCI to upload the docker container of the
invoicer into your own account. Once added, trigger a rebuild of the CircleCI
job and it should succeed and upload the container without issue.

You can then pull and run the container from your repository as follows:

```bash
$ docker run -it securingdevops/invoicer-chapter2
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
$ docker run -it
-e INVOICER_USE_POSTGRES="yes"
-e INVOICER_POSTGRES_USER="invoicer"
-e INVOICER_POSTGRES_PASSWORD="invoicer"
-e INVOICER_POSTGRES_HOST="172.17.0.1"
-e INVOICER_POSTGRES_DB="invoicer"
-e INVOICER_POSTGRES_SSLMODE="disable"
securingdevops/invoicer
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

