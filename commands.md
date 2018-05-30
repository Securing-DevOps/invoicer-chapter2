


pushd ~/learn/secdevops

go install --ldflags '-extldflags "-static"' \
  github.com/actionable-labs/invoicer-chapter2

mkdir -p bin/invoicer
cp "$GOPATH/bin/invoicer-chapter2" bin/invoicer

clear
sudo docker image list | grep -E "actionable|REPOSITORY"
sudo docker container list | grep -E "actionable|STATUS"

sudo docker build -t actionable-labs/invoicer-chapter2 -f Dockerfile .
