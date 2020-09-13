pipeline {
	agent {
		any
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
