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
			sh 'go build'
				}
		}
	}
}
