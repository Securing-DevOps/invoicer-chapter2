pipeline {
	agent any
	stages {
		stage(' GET CODE ') {
			steps{
			checkout scm
			}
		}
		stage(' BUILD SHIT ') {
			agent {
			docker {image 'golang:1.8'}
		}
			steps{
			sh '''export GOPATH_HEAD="$(echo ${GOPATH}|cut -d ':' -f 1)"
			      export GOPATH_BASE="$(echo ${GOPATH}|cut -d ':' -f 1)${gb}"
				mkdir -p "${GOPATH_BASE}"
				mkdir -p "${GOPATH_HEAD}/bin"
				go build'''
				}
		}
	}
}
