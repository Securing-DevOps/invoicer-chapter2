#!/bin/bash
set -e

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER weighttracker;
  CREATE DATABASE weighttracker;
  GRANT ALL PRIVILEGES ON DATABASE weighttracker TO weighttracker;
EOSQL
