#!/bin/sh

    sudo docker network list | grep -E 'secdevops|NAME'
    sudo docker volume list | grep -E 'secdevops|NAME'
    sudo docker container list -a | grep -E "NAMES|secdevops"
    echo $PGSQLID
