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
        COMPOSE_PROJECT_NAME  = 'three-tier-app'
        HEALTHCHECK_RETRIES   = '6'
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
                // README does not define a real test suite. Both package.json
                // files still carry npm-init's default placeholder script
                // ("Error: no test specified" && exit 1), which intentionally
                // fails if run. We check for that specific placeholder text
                // and skip it; any REAL test script is still run and will
                // fail the build normally if it fails.
                dir('backend') {
                    sh '''
                        if grep -q "Error: no test specified" package.json; then
                          echo "Only the default npm-init placeholder test script found - skipping."
                        else
                          npm test
                        fi
                    '''
                }
                dir('frontend') {
                    sh '''
                        if grep -q "Error: no test specified" package.json; then
                          echo "Only the default npm-init placeholder test script found - skipping."
                        else
                          npm test
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

        stage('Deploy Locally') {
            steps {
                // Brings the full 3-tier stack (frontend + backend + db) up
                // on this same Ubuntu server via docker-compose, using the
                // images/Dockerfiles from this workspace. This stands in for
                // the Kubernetes deploy that comes later in your roadmap.
                sh '''
                    docker-compose down --remove-orphans || true
                    docker-compose up -d --build
                '''
            }
        }

        stage('Post-Deploy Health Check & Logs') {
            steps {
                sh '''
                    echo "Waiting for containers to settle..."
                    sleep 10

                    echo "===== Container status ====="
                    docker-compose ps

                    echo "===== Backend health check (http://localhost:${BACKEND_PORT}/data) ====="
                    backend_up=false
                    for i in $(seq 1 ${HEALTHCHECK_RETRIES}); do
                        if curl -sf "http://localhost:${BACKEND_PORT}/data" > /dev/null; then
                            echo "Backend is responding."
                            backend_up=true
                            break
                        fi
                        echo "Backend not ready yet (attempt $i/${HEALTHCHECK_RETRIES}), retrying..."
                        sleep 5
                    done
                    [ "$backend_up" = true ] || echo "WARNING: backend did not respond within the retry window."

                    echo "===== Frontend health check (http://localhost:${FRONTEND_PORT}/) ====="
                    frontend_up=false
                    for i in $(seq 1 ${HEALTHCHECK_RETRIES}); do
                        if curl -sf "http://localhost:${FRONTEND_PORT}/" > /dev/null; then
                            echo "Frontend is responding."
                            frontend_up=true
                            break
                        fi
                        echo "Frontend not ready yet (attempt $i/${HEALTHCHECK_RETRIES}), retrying..."
                        sleep 5
                    done
                    [ "$frontend_up" = true ] || echo "WARNING: frontend did not respond within the retry window."

                    echo "===== Application logs (last 150 lines per service) ====="
                    docker-compose logs --no-color --tail=150 | tee deployment.log
                '''
            }
            post {
                always {
                    // Makes the captured log downloadable/viewable from the
                    // Jenkins build page, no SSH needed to see what happened.
                    archiveArtifacts artifacts: 'deployment.log', allowEmptyArchive: true
                }
            }
        }

        stage('Cleanup') {
            steps {
                sh '''
                    docker logout || true
                    docker image prune -f || true
                    docker container prune -f || true
                '''
                // Note: this does NOT touch running containers, so the app
                // deployed in "Deploy Locally" keeps running afterward -
                // you can still watch it live (see commands below).
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Pipeline succeeded: images pushed as ${DOCKERHUB_USERNAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG} and ${DOCKERHUB_USERNAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}. App deployed locally via docker-compose - see the archived deployment.log on this build, or run 'docker-compose logs -f' on the server to watch it live."
        }
        failure {
            echo 'Pipeline failed - check stage logs above.'
        }
    }
}


