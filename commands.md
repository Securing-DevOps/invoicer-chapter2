

    

### Install invoicer as per book
    
    pushd ~/learn/secdevops

    go install --ldflags '-extldflags "-static"' \
      github.com/actionable-labs/invoicer-chapter2
    
    mkdir -p bin/invoicer
    cp "$GOPATH/bin/invoicer-chapter2" bin/invoicer
    
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

