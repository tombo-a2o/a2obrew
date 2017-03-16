pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'bash -lc "./install.sh rebuild"'
            }
        }
    }
}
