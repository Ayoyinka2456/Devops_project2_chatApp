pipeline {
    agent none  // Prevent default agent; enforce per-stage assignment

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker_login')
    }

    stages {
        stage('Checkout') {
            agent { label 'Jenkins_Server' }
            steps {
                git branch: 'troubleshoot-2', url: 'https://github.com/Ayoyinka2456/Devops_project2_chatApp.git'
            }
        }

        stage('Restore Artifacts') {
            agent { label 'Jenkins_Server' }
            steps {
                script {
                    echo "📦 Restoring artifacts from previous successful build..."
                    copyArtifacts(
                        projectName: env.JOB_NAME,
                        selector: [$class: 'StatusBuildSelector', stable: true],
                        filter: 'TAG.txt',
                        optional: true
                    )
                }
            }
        }
        stage('Dockerize') {
            agent { label 'TF_ANS_Server' }
            steps {
                script {
                    sh '''
                        REPO_DIR="Devops_project2_chatApp"
                        REPO="ayoyinka/chatapp"
                        TAG=1

                        if [ -d "$REPO_DIR" ]; then
                            cd "$REPO_DIR"
                            if [ -d ".git" ]; then
                                echo "🔄 Pulling latest changes in existing repo..."
                                git pull origin troubleshoot-2
                            else
                                echo "⚠️ Directory exists but is not a Git repo. Re-cloning..."
                                cd ..
                                rm -rf "$REPO_DIR"
                                git clone -b troubleshoot-2 https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
                                cd "$REPO_DIR"
                            fi
                        else
                            echo "📥 Cloning repository..."
                            git clone -b troubleshoot-2 https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
                            cd "$REPO_DIR"
                        fi

                        echo "🔍 Determining next Docker tag..."
                        while true; do
                          RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://hub.docker.com/v2/repositories/${REPO}/tags/${TAG}/)
                          if [ "$RESPONSE" -eq 404 ]; then
                            NEXT_TAG=$TAG
                            break
                          else
                            TAG=$((TAG + 1))
                          fi
                        done

                        echo "🐳 Building Docker image with tag: ${NEXT_TAG}"
                        sudo docker build -t ${REPO}:${NEXT_TAG} .
                        echo "🔐 Logging into DockerHub..."
                        sudo docker login -u "${DOCKERHUB_CREDENTIALS_USR}" -p "${DOCKERHUB_CREDENTIALS_PSW}"
                        sudo docker push ${REPO}:${NEXT_TAG}
                        echo "$NEXT_TAG" > "${WORKSPACE}/TAG.txt"
                        cd ..
                    '''
                }
            }
        }

        stage('Terraform') {
            agent { label 'TF_ANS_Server' }
            steps {
                script {
                    # Set the target VPC name
                    TARGET_VPC_NAME="chatapp-vpc"
                    
                    # Check if the Terraform state contains a resource with that name
                    if terraform state list | grep -q "aws_vpc.*${TARGET_VPC_NAME}"; then
                      echo "✅ VPC with name '${TARGET_VPC_NAME}' exists in Terraform state. Proceeding to destroy..."
                      terraform destroy -auto-approve
                    else
                      echo "❌ VPC '${TARGET_VPC_NAME}' not found in Terraform state. No action taken."
                    fi
                }
            }
        }

    post {
        success {
            archiveArtifacts artifacts: 'TAG.txt', fingerprint: true
            echo "✅ Artifacts archived for next build."
        }
        failure {
            echo "❌ Build failed. Check logs for details."
        }
    }
}
