
### Take inventory
    clear
    sudo docker network list | grep weighttrack
    sudo docker volume list | grep weighttrack
    sudo docker container list -a | grep -E "NAMES|wapi|pgadmin|weight|dbg"

    sudo docker image list

### Start existing contaienrs

    sudo docker container start weight-pgsql

    sudo docker container start pgadmin_dock

    sudo docker container start wt-wapi

### Starting temporary container. Self removing
    # Cannot attach a debugger, but can have the app auto reload during development.
    # https://github.com/dotnet/dotnet-docker/blob/master/samples/dotnetapp/dotnet-docker-dev-in-container.md
    sudo docker run \
      --name dbg-wt-wapi \
      --rm -it -p 5001:80 \
      --network weighttrack-net \
      -v ~/Repos/psgivens/misc.git/dnc/:/app/ \
      -w /app/WeightTrack \
      microsoft/dotnet:2.1-sdk \
      dotnet watch run

### Removing containers

    sudo docker container stop weight-pgsql
    sudo docker container rm weight-pgsql

    sudo docker container stop wt-wapi
    sudo docker container rm wt-wapi

    sudo docker container stop pgadmin_dock
    sudo docker container rm pgadmin_dock

### Replace the volume
    sudo docker volume rm pgs_weighttrack
    sudo docker volume create pgs_weighttrack

### Running the database container

    # run the database container
    # https://hub.docker.com/_/postgres/
    sudo docker run \
      --name weight-pgsql \
      --mount source=pgs_weighttrack,target=/var/lib/postgresql/data/pgdata \
      --network weighttrack-net \
      -p 5432:5432 \
      -e POSTGRES_PASSWORD=Password1 \
      -e POSTGRES_USER=samplesam \
      -e POSTGRES_DB=defaultdb \
      -e PGDATA=/var/lib/postgresql/data/pgdata \
      wt-pgsql

### Run the WeightTracker continer
    sudo docker run \
      --name wt-wapi \
      --network weighttrack-net \
      -p 5003:80 \
      wt-wapi

### Create the network
    sudo docker network create --driver bridge weighttrack-net

### Build the wt container
    sudo docker build -t wt-wapi -f WeightTrack/Dockerfile WeightTrack
  
### Build the pgsql database

    sudo docker build -t wt-pgsql -f pgsql/Dockerfile ./pgsql

    #sudo docker pull dpage/pgadmin4
    sudo docker run \
      -it -p 5002:80 \
      --name pgadmin_dock \
      --network weighttrack-net \
      -e "PGADMIN_DEFAULT_EMAIL=user@domain.com" \
      -e "PGADMIN_DEFAULT_PASSWORD=Password1" \
      dpage/pgadmin4

    # run bash in the database container
    sudo docker exec -it weight-pgsql bash

### While logged into database container

    psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"


    
### Create the migration


    # Required dotnet-sdk-2.1.300
    dotnet ef migrations add InitialMigration
    dotnet ef database update



