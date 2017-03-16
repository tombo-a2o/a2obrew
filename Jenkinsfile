pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'bash -c "./install.sh rebuild"'
            }
        }
    }
}
