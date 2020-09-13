pipeline {
	agent {
		docker {image 'golang:1.8'}
	}
	stages {
		stage(' GET CODE ') {
			steps{
			checkout scm
			}
		}
		stage(' BUILD SHIT ') {
		'''sh docker build -t invoicer .
		'''	
			}
	}
}
