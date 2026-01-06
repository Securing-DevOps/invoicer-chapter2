# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

PROJECT		:= github.com/Securing-DevOps/invoicer-chapter2
GO 			:= go
GOLINT 		:= golangci-lint

all: test vet build

build:
	$(GO) build -mod=mod -o bin/invoicer .

install:
	$(GO) install $(PROJECT)

deps:
	$(GO) mod download
	$(GO) mod verify

tidy:
	$(GO) mod tidy

tag: all
	git tag -s $(TAGVER) -a -m "$(TAGMSG)"

lint:
	$(GOLINT) run

vet:
	$(GO) vet ./...

test:
	$(GO) test -v -covermode=count -coverprofile=coverage.out ./...

showcoverage: test
	$(GO) tool cover -html=coverage.out

generate:
	$(GO) generate

clean:
	rm -rf bin/ coverage.out

docker-build:
	docker build -t invoicer:latest .

.PHONY: all test generate clean tag lint vet showcoverage build install deps tidy docker-build
