pipeline {
    agent none  // Prevent default agent; enforce per-stage assignment

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker_login')
    }

    stages {
        stage('Checkout') {
            agent { label 'Jenkins_Server' }
            steps {
                echo "🧹 Cleaning workspace..."
                cleanWs()  // ✅ safer than rm -rf *
                sh "whoami"
                sh "ls && pwd"
                git branch: 'troubleshoot', url: 'https://github.com/Ayoyinka2456/Devops_project2_chatApp.git'
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
                        filter: 'NGINX_IP.txt, TAG.txt, K8S_IP.txt',
                        optional: true
                    )
                }
            }
        }

        stage('Read IPs from Files') {
            agent { label 'TF_ANS_Server' }
            steps {
                script {
                    if (fileExists('NGINX_IP.txt') && fileExists('K8S_IP.txt')) {
                        env.NGINX_IP = readFile('NGINX_IP.txt').trim()
                        env.K8S_IP = readFile('K8S_IP.txt').trim()
                        echo "✅ Loaded NGINX_IP: ${env.NGINX_IP}"
                        echo "✅ Loaded K8S_IP: ${env.K8S_IP}"
                    } else {
                        echo "⚠️ IP files not found. Terraform will create them later."
                    }
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
                                git reset --hard
                                git clean -fd
                                git pull origin troubleshoot
                            else
                                echo "⚠️ Directory exists but is not a Git repo. Re-cloning..."
                                cd ..
                                rm -rf "$REPO_DIR"
                                git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
                                cd "$REPO_DIR"
                            fi
                        else
                            echo "📥 Cloning repository..."
                            git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
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
                    if (env.K8S_IP) {
                        sh '''
                            echo "🧹 Cleaning up previous Kubernetes workstation..."
                            cd Devops_project2_chatApp

                            echo "🔁 Restoring backend.tf for remote state..."
                            cp backup/backend.tf .

                            echo "🔧 Reconfiguring Terraform to use remote state (S3)..."
                            terraform init -reconfigure

                            echo "📊 Running terraform plan to detect changes..."
                            terraform plan -out=tfplan

                            echo "🔍 Checking for actual infrastructure changes..."
                            if grep -q "No changes. Your infrastructure matches the configuration." <<< "$(terraform show -no-color tfplan)"; then
                                echo "✅ No changes detected in Terraform files. Skipping apply."
                            else
                                echo "⚠️ Changes detected. Proceeding to apply."
                                terraform apply -auto-approve tfplan
                            fi

                            echo "🔐 Fixing PEM file permissions..."
                            chmod 400 Devops_project2_chatApp/k8s-admin-setup/devops_1.pem

                            echo "🚀 Connecting to remote Kubernetes workstation to clean up..."
                            ssh -o StrictHostKeyChecking=no -i Devops_project2_chatApp/k8s-admin-setup/devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'
if command -v eksctl &> /dev/null; then
    echo "🗑 Deleting existing Kubernetes cluster resources..."
    kubectl delete all --all --all-namespaces
    kubectl delete pvc --all --all-namespaces
    kubectl delete configmap --all --all-namespaces
    kubectl delete secret --all --all-namespaces
    kubectl delete ingress --all --all-namespaces
    sleep 120
    eksctl delete cluster --name chatapp-cluster --region us-east-2 --force
    sleep 180
else
    echo "⚠️ eksctl not found on remote instance."
fi
ENDSSH
                        '''
                    } else {
                        sh '''
                            echo "🚀 Running Terraform..."
                            cd Devops_project2_chatApp/remote-state
                            terraform init
                            terraform apply -auto-approve
                            sleep 60
                            cd ../
                            terraform init
                            terraform apply -auto-approve
                            {
                              echo "===== Backup on $(date) =====";
                              cat terraform.tfstate;
                              echo; echo; echo; echo; echo;
                            } >> /${WORKSPACE}/tfstate-protection.txt
                            
                          #  aws s3 cp terraform.tfstate s3://devops-project2-chatapp-tfstate/terraform.tfstate \
                          #      --content-type application/json \
                          #      --metadata-directive REPLACE
                            
                            cp backup/backend.tf .
                            yes | terraform init -reconfigure
                            terraform apply -auto-approve

                            sleep 120
                            NGINX_IP=$(terraform output -raw nginx_public_ip)
                            K8S_IP=$(terraform output -raw k8s_workstation_public_ip)
                            if [[ -z "$NGINX_IP" || -z "$K8S_IP" ]]; then
                                echo "❌ ERROR: IPs are empty"
                                exit 1
                            fi
                            echo "$NGINX_IP" > "${WORKSPACE}/NGINX_IP.txt"
                            echo "$K8S_IP" > "${WORKSPACE}/K8S_IP.txt"
                            chmod 400 k8s-admin-setup/devops_1.pem
                            cat > hosts.ini <<EOF
[nginx]
$NGINX_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"
[k8s-workstation]
$K8S_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"
EOF
                            echo "✅ hosts.ini created"
                            scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem -r ${WORKSPACE}/Devops_project2_chatApp/k8s-admin-setup ec2-user@$K8S_IP:/home/ec2-user/
                            scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ${WORKSPACE}/TAG.txt ec2-user@$K8S_IP:/home/ec2-user/k8s-admin-setup
                            scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ${WORKSPACE}/NGINX_IP.txt ${WORKSPACE}/K8S_IP.txt ec2-user@$K8S_IP:/home/ec2-user/k8s-admin-setup
                        '''
                    }
                }
            }
        }

        stage('Ansible') {
            agent { label 'TF_ANS_Server' }
            steps {
                dir('k8s-admin-setup') {
                    sh '''
                        ansible-playbook -i hosts.ini 01-*
                        sleep 120
                        ansible-playbook -i hosts.ini 02-*
                        sleep 120
                        ansible-playbook -i hosts.ini 03-*
                        sleep 120
                        ansible-playbook -i hosts.ini 04-*
                        sleep 120
                    '''
                }
            }
        }

        stage('K8s-workstation -> NGINX') {
            agent { label 'TF_ANS_Server' }
            steps {
                dir('k8s-admin-setup') {
                    sh '''
                        ssh -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'
cd /home/ec2-user/k8s-admin-setup
chmod +x service_info.sh
./service_info.sh
ENDSSH

                        scp -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup/SVC_*.txt .
                        scp -o StrictHostKeyChecking=no -i devops_1.pem SVC_DNS.txt SVC_PORT.txt nginx-conf.sh ec2-user@${NGINX_IP}:/home/ec2-user/

                        ssh -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${NGINX_IP} <<'ENDSSH'
chmod +x nginx-conf.sh
./nginx-conf.sh
sudo systemctl status nginx
ENDSSH
                    '''
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'TAG.txt, K8S_IP.txt, NGINX_IP.txt', fingerprint: true
            echo "✅ Artifacts archived for next build."
        }
        failure {
            echo "❌ Build failed. Check logs for details."
        }
    }
}
