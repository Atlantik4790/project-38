pipeline {

    agent any

    environment {
        DOCKERHUB_USERNAME = 'Atlantik4790'

        BACKEND_IMAGE  = "${DOCKERHUB_USERNAME}/project-38-backend"
        FRONTEND_IMAGE = "${DOCKERHUB_USERNAME}/project-38-frontend"

        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Backend Image') {
            steps {
                sh '''
                    docker build \
                    --target backend \
                    -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                    -t ${BACKEND_IMAGE}:latest \
                    .
                '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    docker build \
                    --target frontend \
                    -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                    -t ${FRONTEND_IMAGE}:latest \
                    .
                '''
            }
        }

        stage('Push Images to DockerHub') {
            steps {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-creds'',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {

                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login \
                        -u "$DOCKER_USERNAME" \
                        --password-stdin

                        docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker push ${BACKEND_IMAGE}:latest

                        docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                        docker push ${FRONTEND_IMAGE}:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy Application') {
            steps {
                sh '''
                    docker compose down || true
                    docker compose up -d
                '''
            }
        }

    }

    post {

        success {
            echo 'Project-38 CI/CD pipeline completed successfully!'
        }

        failure {
            echo 'Project-38 pipeline failed. Check the Jenkins console output.'
        }

        always {
            sh 'docker image prune -f || true'
        }
    }
}
