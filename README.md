Securing DevOps's invoicer
==========================

A simple REST API that manages invoices.

Pull the live container using `docker pull securingdevops/invoicer`.

Build
-----

Build a statically linked invoicer binary. Requires Go 1.6.

```bash
$ mkdir bin
$ go build --ldflags '-extldflags "-static"' -o bin/invoicer .
```

Then build the container.
```bash
$ docker build -t securingdevops/invoicer .
```

Configure
---------

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
