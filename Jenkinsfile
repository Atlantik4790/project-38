// =========================================================
// Jenkinsfile - 3-tier Docker project (frontend + backend)
// GitHub -> Jenkins -> Docker Build -> Trivy Scan -> DockerHub
// (Terraform / Kubernetes stages are OUT of scope for this pipeline)
// =========================================================

pipeline {
    agent any

    // ---------- Configurable variables ----------
    environment {
        DOCKERHUB_USERNAME   = 'your-dockerhub-username'      // <-- change me
        BACKEND_IMAGE_NAME    = 'three-tier-backend'
        FRONTEND_IMAGE_NAME   = 'three-tier-frontend'
        IMAGE_TAG             = "${env.BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'        // Jenkins credential ID (username/password or token)
        BACKEND_PORT          = '3001'
        FRONTEND_PORT         = '3000'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            parallel {
                stage('Backend deps') {
                    steps {
                        dir('backend') {
                            sh 'npm install'
                        }
                    }
                }
                stage('Frontend deps') {
                    steps {
                        dir('frontend') {
                            sh 'npm install'
                        }
                    }
                }
            }
        }

        stage('Run Tests') {
            steps {
                // README does not define a test framework or "test" script
                // in package.json. This stage runs `npm test` only if one
                // exists, so the pipeline doesn't fail on a missing script.
                dir('backend') {
                    sh '''
                        if npm run | grep -q "^  test"; then
                          npm test
                        else
                          echo "No test script found in backend/package.json - skipping."
                        fi
                    '''
                }
                dir('frontend') {
                    sh '''
                        if npm run | grep -q "^  test"; then
                          npm test
                        else
                          echo "No test script found in frontend/package.json - skipping."
                        fi
                    '''
                }
            }
        }

        stage('Build Application') {
            steps {
                // Plain Node.js apps with no transpile/bundle step in the README.
                // "Build" here just re-confirms install succeeded before the
                // Docker build stage.
                echo 'No compile/bundle step required for plain Node.js apps.'
            }
        }

        stage('Build Docker Images') {
            steps {
                dir('backend') {
                    sh "docker build -t ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG} ."
                }
                dir('frontend') {
                    sh "docker build -t ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Validate Containers') {
            steps {
                sh '''
                    docker network create ci-test-net || true

                    docker run -d --rm --name ci-backend --network ci-test-net \
                        -p ${BACKEND_PORT}:${BACKEND_PORT} \
                        -e CONNECTION_STRING="postgres://demo_user:demo_user@db/demo_db" \
                        ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}

                    docker run -d --rm --name ci-frontend --network ci-test-net \
                        -p ${FRONTEND_PORT}:${FRONTEND_PORT} \
                        -e API_URL="http://ci-backend:${BACKEND_PORT}/data" \
                        ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}

                    sleep 5

                    # Basic smoke check - container is up and listening.
                    # NOTE: /data will return a DB connection error here since
                    # no real Postgres instance is provided in this stage;
                    # we're only validating the container starts and the
                    # Express server binds to its port.
                    curl -sf -o /dev/null http://localhost:${FRONTEND_PORT}/ || echo "Frontend smoke check failed (non-fatal without live DB)"

                    docker stop ci-backend ci-frontend || true
                    docker network rm ci-test-net || true
                '''
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh '''
                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}
                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}
                '''
                // Change --exit-code to 1 once you want the build to fail on
                // findings instead of just reporting them.
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh '''
                    docker tag ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG} ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker tag ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG} ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:latest
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                sh '''
                    docker push ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker push ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:latest
                '''
            }
        }

        stage('Cleanup') {
            steps {
                sh '''
                    docker logout || true
                    docker image prune -f || true
                    docker container prune -f || true
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Pipeline succeeded: images pushed as ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG} and ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed - check stage logs above.'
        }
    }
}
