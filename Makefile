# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

PROJECT		:= github.com/Securing-DevOps/invoicer
GO 			:= GO15VENDOREXPERIMENT=1 go
GOGETTER	:= GOPATH=$(shell pwd)/.tmpdeps go get -d
GOLINT 		:= golint

all: test vet generate install

install:
	$(GO) install $(PROJECT)

go_vendor_dependencies:
	$(GOGETTER) github.com/gorilla/mux
	$(GOGETTER) github.com/jinzhu/gorm
	$(GOGETTER) github.com/jinzhu/gorm/dialects/postgres
	$(GOGETTER) github.com/jinzhu/gorm/dialects/sqlite
	echo 'removing .git from vendored pkg and moving them to vendor'
	find .tmpdeps/src -type d -name ".git" ! -name ".gitignore" -exec rm -rf {} \; || exit 0
	cp -ar .tmpdeps/src/* vendor/
	rm -rf .tmpdeps

tag: all
	git tag -s $(TAGVER) -a -m "$(TAGMSG)"

lint:
	$(GOLINT) $(PROJECT)

vet:
	$(GO) vet $(PROJECT)

test:
	$(GO) test -covermode=count -coverprofile=coverage.out $(PROJECT)

showcoverage: test
	$(GO) tool cover -html=coverage.out

generate:
	$(GO) generate

.PHONY: all test generate clean

