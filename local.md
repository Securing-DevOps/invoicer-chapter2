

### Notes for next time


### Take inventory 
    clear
    ./status.sh 

    clear
    sudo docker network list | grep secdevops
    sudo docker volume list | grep secdevops
    sudo docker container list -a | grep -E "NAMES|secdevops"
    echo $PGSQLID

    PS1="#> "

    sudo docker image list

### Running the database container

    # run the database container
    # https://hub.docker.com/_/postgres/
    sudo docker run \
      --name secdevops-pgsql \
      --mount source=secdevops_pgsql,target=/var/lib/postgresql/data/pgdata \
      --network secdevops-net \
      -p 5432:5432 \
      -e POSTGRES_USER='invoicer' \
      -e POSTGRES_PASSWORD='Password1' \
      -e POSTGRES_DB='invoicer' \
      -e PGDATA=/var/lib/postgresql/data/pgdata \
      --rm \
      -d \
      invoicer_pgsql:latest

    
    # run bash in the database container
    sudo docker exec -it secdevops-pgsql bash

### While logged into database container

    psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"

### Running pgadmin4

    #sudo docker pull dpage/pgadmin4
    sudo docker run \
      -p 5002:80 \
      --name pgadmin_dock \
      --network secdevops-net \
      -e "PGADMIN_DEFAULT_EMAIL=user@domain.com" \
      -e "PGADMIN_DEFAULT_PASSWORD=Password1" \
      --rm \
      -d \
      dpage/pgadmin4

### Running the invoicer-chapter2 example

    PGSQLID="172.19.0.2"

    PGSQLID=$(sudo docker container inspect secdevops-pgsql \
                | jq '.[0].NetworkSettings.Networks."secdevops-net".IPAddress' \
                | tr -d '"')

    echo $(sudo docker container inspect secdevops-pgsql \
                | jq '.[0].NetworkSettings.Networks."secdevops-net".IPAddress') \
                | tr -d '"'

    PGSQLID=secdevops-pgsql

    # Run with postgresdatabase
    sudo docker run \
      --name secdevops-invoicer \
      -p 8080:8080 \
      -e INVOICER_USE_POSTGRES="yes" \
      -e INVOICER_POSTGRES_USER="invoicer" \
      -e INVOICER_POSTGRES_PASSWORD="Password1" \
      -e INVOICER_POSTGRES_HOST=$PGSQLID \
      -e INVOICER_POSTGRES_DB="invoicer" \
      -e INVOICER_POSTGRES_SSLMODE="disable" \
      --network secdevops-net \
      --rm \
      -it \
      --entrypoint sh \
      actionablelabs/invoicer-chapter2 

    # Run with sqlite database
    sudo docker run \
      --name secdevops-invoicer \
      -p 8080:8080 \
      --network secdevops-net \
      --rm \
      -d \
      actionablelabs/invoicer-chapter2

    # run bash in the database container
    sudo docker exec -it -u root -w /root secdevops-invoicer /bin/sh 

    sudo docker exec -it secdevops-invoicer /bin/sh

### Teardown
    sudo docker volume rm secdevops_pgsql 
    sudo docker volume create secdevops_pgsql 

    sudo docker container stop secdevops-pgsql

    sudo docker container rm secdevops-pgsql

    sudo docker container stop secdevops_invoicer

    sudo docker container rm secdevops_invoicer

### Create a netowrk
    sudo docker network create --driver bridge secdevops-net


### Build invoicer db image

    pushd pgsql
    sudo docker build -t invoicer_pgsql .

### Install invoicer as per book
    
    pushd ~/learn/secdevops

    go install --ldflags '-extldflags "-static"' \
      github.com/actionable-labs/invoicer-chapter2
    
    mkdir -p bin
    cp "$GOPATH/bin/invoicer-chapter2" bin/invoicer
    
    sudo docker build --no-cache -t actionablelabs/invoicer-chapter2 .

### While logged into database container

    psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"

### Report status of docker containers locally

    clear
    sudo docker image list | grep -E "actionable|REPOSITORY"
    sudo docker container list | grep -E "actionable|STATUS"
    
### Build the docker container

    sudo docker build -t actionable-labs/invoicer-chapter2 -f Dockerfile .
    
### Remove the docker container locally

    sudo docker container stop invoicer-chapter2
    sudo docker container rm invoicer-chapter2
    
### Run the docker container locally

    ### Run docker container
        sudo docker run -it \
          --name invoicer-chapter2 \
          -p 8080:8080 \
          actionable-labs/invoicer-chapter2


### Run locally

    ./bin/invoicer/invoicer-chapter2

### Submit and receive an invoice

    curl -X POST --data '{"is_paid": false, "amount": 1664, "due_date": "2016-05-07T23:00:00Z", "charges": [ { "type":"blood work", "amount": 1664, "description": "blood work" } ] }' http://localhost:8080/invoice

    curl -X GET http://localhost:8080/invoice/1

