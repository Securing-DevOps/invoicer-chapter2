# PatientPop Monolith in Docker

###*Some assembly required*
The scripts in this directory will create and run 
- Docker network called patientpop-net
- Docker volume for mysql db called mysql_patientpop
- Docker image for mysql called patientpop_mysql
- Docker container for mysql called patientpop_mysql_db
- Docker image for patientpop called patientpop_monolith
- Docker container for monolith called patientpop_monolith_www
- Fetch dmysql directory from official repository by mysql team
- Fetch config files from patientpopinc/dev-tools repository

This has not been thoroughly road tested, so take care. 

Here are some ideas for improvement
- Remove the composer dependency to github. Then composer can be run as part of the Dockerfile.
- Mount the application code base instead of copying it 
- Docker mysql volume to be tarballed and stored somewhere

### Tearing things down 
If you get stuck, it is good to be able to tear things down.

    # Remove, then create, a docker volume
    sudo docker volume rm mysql_patientpop
    sudo docker volume create mysql_patientpop

    # Stopping and removing the db containers
    sudo docker container stop patientpop_mysql_db
    sudo docker container rm patientpop_mysql_db

    # Stopping and removing the monolith container
    sudo docker container stop patientpop_monolith_www
    sudo docker container rm patientpop_monolith_www

## Building the system
To create the docker container, run the create_phpdoc.sh script from this directory. 

    ./create_phpdoc.sh

This script will ask your for 
- your github credentials
- sudo credentials
- information for the ssl credentials

### Build mysql container
    sudo docker build -t patientpop_mysql ./dmysql/ | tee dmysql.log
    
### Create a docker network  
    sudo docker network create --driver bridge patientpop-net 

## Running the system

### Run the mysql container
    echo "Enter password for mysql user 'bob':"
    read -s MYSQL_PASSWORD

    clear
    sudo docker run --name=patientpop_mysql_db \
      -p 3306:3306 \
      -e MYSQL_ROOT_PASSWORD='abc123' \
      -e MYSQL_DATABASE=patientpop \
      -e MYSQL_USER=bob \
      -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
      --network patientpop-net \
      --mount source=mysql_patientpop,target=/var/lib/mysql \
      -d patientpop_mysql 

### Inspecting the mysql container
    sudo docker exec -it patientpop_mysql_db bash


### Run the monolith container
    sudo docker run -it --name patientpop_monolith_www \
      --network patientpop-net \
      -p 80:80 \
      -p 443:443 \
      patientpop_monolith

    sudo docker container start -i patientpop_monolith_www

# Post Installation - Cookbook

Are you using the version of php you think you are?
https://tecadmin.net/switch-between-multiple-php-version-on-ubuntu/

Information about php-cs-fixer can be found here: http://cs.sensiolabs.org/#installation

### Find the other computer on the network
These are run from within the monolith container

    apt install -y iputils-ping

    clear; ping -c 2 patientpop_mysql_db

### Run composer
These are run from within the monolith container

    # You will be asked for your github credentials
    composer update

    composer global require friendsofphp/php-cs-fixer
    composer install

### Permissions
These are run from within the monolith container

    chmod -R 0777 /app/code/patientpop/laravel/app/storage/
    chmod 777 /app/code/patientpop/laravel/admin/tmp
    chmod 777 /app/code/patientpop/laravel/patientpop/tmp
    chmod 777 /app/code/patientpop/laravel/api/tmp


### Restarting apache2 and memcache
These are run from within the monolith container

    apache2ctl restart
    service memcached restart

### Initialie the database
    # Be sure to update your database settings before calling migrate.
    # This is not necessary if you are mounting a Docker volume
    php artisan migrate

### Connecting to MySql
    # https://dev.mysql.com/doc/refman/5.6/en/connecting.html
    sudo docker exec -it patientpop_mysql_db mysql -u bob patientpop -p

    # Make sure to enter your password for sudo, if necessary
    # Then enter the password for the database user that you entered earlier. 

### Install users in the Mysql database
The script below creates the following log in.
- https://ppadmin-dev.patiendpop.com
- Login: bob.marley@patientpop.com
- Password: Password1


    INSERT INTO users
    (email, username, password, type, firstname, lastname, state, access, is_demo, department, system_account, editable_account)
    VALUES
    ('bob.marley@patientpop.com', 'bob marley', '$2y$10$mlLMjq2Qtv.uahfQWToaEehST3IAaat1DdMxHfMyAiUFJwa1aOmrO', 'INTERNAL', 'Name', 'Lastname', 'ACTIVE', 'ar1,aw1', 1, 'ADMIN', 0, 1);

### Exit mysql
    \q

### Snippets for the mysql container

    ## First add this option to your docker run for mysql
    # --mount type=bind,source=/path/to/data/dump/,target=/mnt/data \

    ## Importing the database
    # mysql -u bob patientpop < /mnt/data/prod_2017-08-04.sql -p


### Installing the mysql client
    sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty universe'
    sudo apt-get update
    sudo apt install mysql-client-5.6



# Usful parts for importing data

    # Run the mysql container
    echo "Enter password for mysql user 'bob':"
    read -s MYSQL_PASSWORD


    # Remove, then create, a docker volume
    sudo docker volume rm mysql_patientpop
    sudo docker volume create mysql_patientpop

    # Stopping and removing the db containers
    sudo docker container stop patientpop_mysql_db

    sudo docker container rm patientpop_mysql_db


    clear
    sudo docker run --name=patientpop_mysql_db \
      -p 3306:3306 \
      -e MYSQL_ROOT_PASSWORD='abc123' \
      -e MYSQL_DATABASE=patientpop \
      -e MYSQL_USER=bob \
      -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
      --network patientpop-net \
      --mount type=bind,source=/home/psgivens/Downloads/dump/,target=/mnt/data \
      --mount source=mysql_patientpop,target=/var/lib/mysql \
      -d patientpop_mysql 

    sudo docker container start patientpop_mysql_db

    ### Inspecting the mysql container
    sudo docker exec -it patientpop_mysql_db bash

    ## First add this option to your docker run for mysql

    ## Importing the database
    mysql -u bob patientpop < /mnt/data/pp_slimmed_dumpfile.sql -p


    mysql -u bob patientpop < /mnt/data/bare_patientpop_2018-04-10.sql -p

    mysql -u bob patientpop < /mnt/data/pp_data_dumpfile.sql -p


# Useful parts for archiving volume

### Archive

    # Will create /tmp/ppdb.tar.bz2
    sudo docker run -v patientpop_mysql_db:/volume -v /tmp/:/backup --rm loomchild/volume-backup backup ppdb

    mkdir -p ~/Backup
    sudo mv /tmp/ppdb.tar.bz2 ~/Backup

### Restoring

    # Will restore /tmp/ppdb.tar.bz2
    sudo docker run -v patientpop_mysql_db:/volume -v /tmp/:/backup --rm loomchild/volume-backup backup - >  ppdb











