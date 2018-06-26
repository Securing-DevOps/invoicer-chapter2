#!/bin/bash
set -e

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER invoicer;
  CREATE DATABASE invoicer;
  GRANT ALL PRIVILEGES ON DATABASE invoicer TO invoicer;
EOSQL
