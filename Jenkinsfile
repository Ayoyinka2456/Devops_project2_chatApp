pipeline {
    agent none  // Prevent default agent; enforce per-stage assignment
    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker_login')
    }
    stages {
        stage('Checkout') {
            agent {
                label 'Jenkins_Server'
            }
            steps {
                git branch: 'troubleshoot', url: 'https://github.com/Ayoyinka2456/Devops_project2_chatApp.git'
            }
        }
        stage('Restore Artifacts') {
            agent {
                label 'Jenkins_Server'
            }
            steps {
                script {
                    echo "📦 Attempting to restore TAG.txt from last successful build..."
                    try {
                        copyArtifacts(
                            projectName: env.JOB_NAME,
                            selector: [$class: 'StatusBuildSelector', stable: true],
                            filter: 'TAG.txt, NGINX_IP.txt, K8S_IP.txt',
                            optional: true
                        )
                        echo "✅ TAG.txt, NGINX_IP.txt, K8S_IP.txt restored"
                    } catch (e) {
                        echo "⚠️ No previous build found to restore TAG.txt. Skipping..."
                    }
                }
            }
        }
        stage('Read IPs from Files') {
            agent {
                label 'TF_ANS_Server'
            }
            steps {
                script {
                    if (fileExists('NGINX_IP.txt') && fileExists('K8S_IP.txt')) {
                        def nginxIpContent = readFile('NGINX_IP.txt').trim()
                        def k8sIpContent = readFile('K8S_IP.txt').trim()
                        def ipRegex = /^([0-9]{1,3}\.){3}[0-9]{1,3}$/
                        if (nginxIpContent ==~ ipRegex && k8sIpContent ==~ ipRegex) {
                            env.NGINX_IP = nginxIpContent
                            env.K8S_IP = k8sIpContent
                            echo "✅ Loaded NGINX_IP: ${env.NGINX_IP}"
                            echo "✅ Loaded K8S_IP: ${env.K8S_IP}"
                        } else {
                            echo "⚠️ One or both IPs are invalid. Skipping IP load."
                        }
                    } else {
                        echo "⚠️ IP files not found. Terraform will create them later."
                    }
                }
            }
        }
        stage('Dockerize') {
            agent {
                label 'TF_ANS_Server'
            }
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
                    '''
                }
            }
        }
        stage('Terraform') {
            agent {
                label 'TF_ANS_Server'
            }
            steps {
                script {
                    if (env.K8S_IP) {
                        sh '''
                            echo "🧹 Cleaning up previous Kubernetes workstation..."
                            cd Devops_project2_chatApp

                            echo "🔐 Fixing PEM file permissions..."
                            chmod 400 k8s-admin-setup/devops_1.pem
                            echo "🚀 Connecting to remote Kubernetes workstation to clean up..."
                            cd k8s-admin-setup
                            ls
                            pwd
                            ssh -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'
if command -v eksctl &> /dev/null; then
    echo "🗑 Deleting existing Kubernetes cluster resources..."
    kubectl delete deployment chatapp-deployment || true
    kubectl delete service chatapp-service || true


    sleep 120

    if eksctl get cluster --name chatapp-cluster --region us-east-2 &>/dev/null; then
        eksctl delete cluster --name chatapp-cluster --region us-east-2 --force
    else
        echo "⚠️ Cluster 'chatapp-cluster' not found. Skipping deletion."
    fi

    sleep 180
else
    echo "⚠️ eksctl not found on remote instance."
fi
ENDSSH

                            terraform apply -auto-approve
                            sleep 120
                        '''
                    } else {
                        sh '''
                            echo "🚀 Running Terraform..."
                            cd Devops_project2_chatApp
                            pwd
                            TARGET_VPC_NAME="chatapp-vpc"

                            if [ -f terraform.tfstate ]; then
                                echo "📄 terraform.tfstate file found. Checking for VPC named '${TARGET_VPC_NAME}'..."
                                if terraform state list | grep -q "aws_vpc.*${TARGET_VPC_NAME}"; then
                                    echo "✅ VPC '${TARGET_VPC_NAME}' exists in state. Destroying..."
                                    terraform destroy -auto-approve
                                    sleep 60
                                fi
                            else
                                echo "🚫 No terraform.tfstate found. Running terraform init and apply..."
                                terraform init
                            fi

                            terraform apply -auto-approve
                            sleep 120
                        '''
                    }
                    sh '''
                        cd Devops_project2_chatApp
                        NGINX_IP=$(terraform output -raw nginx_public_ip)
                        K8S_IP=$(terraform output -raw k8s_workstation_public_ip)

                        if [[ -z "$NGINX_IP" || -z "$K8S_IP" ]]; then
                            echo "❌ ERROR: IPs are empty"
                            exit 1
                        fi

                        echo "$NGINX_IP" > "${WORKSPACE}/NGINX_IP.txt"
                        echo "$K8S_IP" > "${WORKSPACE}/K8S_IP.txt"

                        chmod 400 k8s-admin-setup/devops_1.pem
                        cd k8s-admin-setup

                        cat > hosts.ini <<EOF
[nginx]
$NGINX_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"

[k8s_workstation]
$K8S_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"
EOF
                        echo "✅ hosts.ini created"
                    '''
                }
            }
        }
        stage('Ansible') {
            agent {
                label 'TF_ANS_Server'
            }
            steps {
                dir('Devops_project2_chatApp/k8s-admin-setup') {
                    sh '''
                        ansible-playbook -i hosts.ini 01-* -e "workspace=${WORKSPACE}"
                        sleep 60
                        ansible-playbook -i hosts.ini 02-* -e "workspace=${WORKSPACE}"
                        sleep 30
                        ansible-playbook -i hosts.ini 03-* -e "workspace=${WORKSPACE}"
                        sleep 300
                    '''
                }
            }
        }
        stage('Run Deployment') {
            agent {
                label 'TF_ANS_Server'
            }
            steps {
                dir('Devops_project2_chatApp') {
                    sh '''
                        NGINX_IP=$(terraform output -raw nginx_public_ip)
                        K8S_IP=$(terraform output -raw k8s_workstation_public_ip)

                        scp -i k8s-admin-setup/devops_1.pem ${WORKSPACE}/K8S_IP.txt ${WORKSPACE}/TAG.txt ${WORKSPACE}/NGINX_IP.txt ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup/
                        ssh -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'
cd /home/ec2-user/k8s-admin-setup/
sudo chown ec2-user:ec2-user K8S_IP.txt
sudo chown ec2-user:ec2-user NGINX_IP.txt
sudo chown ec2-user:ec2-user TAG.txt
chmod 400 devops_1.pem



for f in TAG.txt K8S_IP.txt NGINX_IP.txt; do
    [ ! -f "$f" ] && echo "❌ $f not found!" && exit 1
done

export TAG=$(cat TAG.txt | tr -d '[:space:]')
export K8S_IP=$(cat K8S_IP.txt | tr -d '[:space:]')
export NGINX_IP=$(cat NGINX_IP.txt | tr -d '[:space:]')

echo "✅ TAG=$TAG"
echo "✅ K8S_IP=$K8S_IP"
echo "✅ NGINX_IP=$NGINX_IP"

ls -la
pwd
python3 render.py && \
sudo chown ec2-user:ec2-user deployment.yml && \
echo "Deploying pods" && \
kubectl apply -f deployment.yml

sleep 60

echo "🔍 Getting service DNS and port..."
pwd
ls -la
SVC_DNS=$(kubectl get svc chatapp-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo "$SVC_DNS" > SVC_DNS.txt

SVC_PORT=$(kubectl get svc chatapp-service -o jsonpath="{.spec.ports[0].port}")
echo "$SVC_PORT" > SVC_PORT.txt

echo "${SVC_DNS}:${SVC_PORT}" > external-ip.txt

chown ec2-user:ec2-user SVC_DNS.txt SVC_PORT.txt external-ip.txt
echo "✅ Saved DNS to SVC_DNS.txt and Port to SVC_PORT.txt"

scp -o StrictHostKeyChecking=no -i devops_1.pem SVC* nginx-conf.sh ec2-user@${NGINX_IP}:/home/ec2-user/
ENDSSH
                    '''
                }
            }
        }
        stage('TF_ANS_Server -> NGINX') {
            agent {
                label 'TF_ANS_Server'
            }
            steps {
                dir('Devops_project2_chatApp') {
                    sh '''
                        NGINX_IP=$(terraform output -raw nginx_public_ip)
                        K8S_IP=$(terraform output -raw k8s_workstation_public_ip)
                        
                        ssh -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ec2-user@${NGINX_IP} <<'ENDSSH'
chmod +x nginx-conf.sh
./nginx-conf.sh
sudo systemctl restart nginx
ENDSSH
                        echo "✅ Click here :-> http://${NGINX_IP}:3000"
                    '''
                }
            }
        }
    }
    post {
        success {
            node('TF_ANS_Server') {
                archiveArtifacts artifacts: 'TAG.txt', fingerprint: true
                echo "✅ Artifacts archived for next build."
            }
        }
        failure {
            node('TF_ANS_Server') {
                echo "❌ Build failed. Check logs for details."
            }
        }
    }
}
