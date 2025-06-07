pipeline {
    agent {
        label 'TF_ANS_Server'
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker_login')
        // DOCKER_IMAGE = "${DOCKERHUB_CREDENTIALS_USR}/chatApp:1"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Cleaning workspace..."
                sh "whoami"
                sh "sudo rm -rf *"
                sh "ls && pwd"
                git branch: 'troubleshoot', url: 'https://github.com/Ayoyinka2456/Devops_project2_chatApp.git'
            }
        }

        stage('Restore Artifacts') { // UPDATED NAME
            steps {
                script {
                    echo "Restoring artifacts from previous successful build..."
                    copyArtifacts(
                        projectName: env.JOB_NAME,
                        selector: [$class: 'StatusBuildSelector', stable: true],
                        filter: 'NGINX_IP, TAG.txt, K8S_IP.txt', // UPDATED TO INCLUDE K8S_IP
                        // filter: 'K8S_IP.txt', // UPDATED TO INCLUDE K8S_IP
                        optional: true
                    )
                }
            }
        }

        stage('Dockerize') {
            steps {
                script {
                    sh '''
                        REPO="ayoyinka/chatapp"
                        TAG=1
                        
                        echo "Checking for the next available Docker tag for $REPO..."
                        
                        while true; do
                          RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://hub.docker.com/v2/repositories/${REPO}/tags/${TAG}/)
                        
                          if [ "$RESPONSE" -eq 404 ]; then
                            echo "✅ Tag ${TAG} does NOT exist. You can use this as the next tag."
                            NEXT_TAG=$TAG
                            break
                          else
                            echo "❌ Tag ${TAG} already exists. Checking next..."
                            TAG=$((TAG + 1))
                          fi
                        done
                        
                        # Optional: Use this tag to build and push
                        echo "Building Docker image with tag: ${NEXT_TAG}"
                        docker build -t ${REPO}:${NEXT_TAG} .
                        docker login -u \"${DOCKERHUB_CREDENTIALS_USR}\" -p \"${DOCKERHUB_CREDENTIALS_PSW}\"
                        docker push ${REPO}:${NEXT_TAG}
                        echo "$NEXT_TAG" > ${WORKSPACE}/TAG.txt
                        # writeFile file: 'TAG.txt', text: NEXT_TAG.toString()
                    '''
                }
            }
        }
        stage('Terraform') {
            steps {
                script {
                    // BEGIN ADDED CLEANUP BLOCK
                    if (fileExists('K8S_IP.txt')) {
                        env.K8S_IP = readFile('K8S_IP.txt').trim()
                        echo "Loaded previous K8S_IP: ${env.K8S_IP}"

                        sh '''
                            echo "Cleaning up previous K8s workstation..."
                            chmod 400 Devops_project2_chatApp/k8s-admin-setup/devops_1.pem
                            # K8S_IP=$(terraform output -raw k8s-workstation_public_ip)

                            ssh -o StrictHostKeyChecking=no -i Devops_project2_chatApp/k8s-admin-setup/devops_1.pem ec2-user@${env.K8S_IP} <<'ENDSSH'
echo "Connected to K8s workstation"
if command -v eksctl &> /dev/null; then
    kubectl delete all --all --all-namespaces
    kubectl delete pvc --all --all-namespaces
    kubectl delete configmap --all --all-namespaces
    kubectl delete secret --all --all-namespaces
    kubectl delete ingress --all --all-namespaces
    sleep 120
    eksctl delete cluster --name chatapp-cluster --region us-east-2 --force
    sleep 180
else
    echo "eksctl not found on remote instance."
fi
ENDSSH
                        '''
                    } else {
                        echo "No K8S_IP.txt found, skipping K8s cleanup."
                    }
                    // END ADDED CLEANUP BLOCK

                    sh '''
                        echo "Entering Terraform"
                        if [ -d "Devops_project2_chatApp" ]; then
                            cd Devops_project2_chatApp
                            terraform destroy -auto-approve && rm -f terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
                            sleep 120
                            cd ../ && rm -rf Devops_project2_chatApp
                            git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
                            cd Devops_project2_chatApp/
                        else
                            git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp.git
                            cd Devops_project2_chatApp/
                        fi
                        terraform init
                        terraform apply -auto-approve
                        sleep 300

                        NGINX_IP=$(terraform output -raw nginx_public_ip)
                        K8S_IP=$(terraform output -raw k8s_workstation_public_ip)

                        echo "$NGINX_IP" > ${WORKSPACE}/NGINX_IP.txt
                        echo "$K8S_IP" > ${WORKSPACE}/K8S_IP.txt

                        chmod 400 k8s-admin-setup/devops_1.pem
                        
      
                        # Validate the values
                        if [[ -z "$NGINX_IP" || -z "$K8S_IP" ]]; then
                          echo "❌ ERROR: NGINX_IP.txt and/or K8S_IP.txt is empty or missing"
                          exit 1
                        fi
                        
                        # Create the hosts.ini file
                        cat > hosts.ini <<EOF
                        [nginx]
                        $NGINX_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"
                        
                        [k8s-workstation]
                        $K8S_IP ansible_user=ec2-user ansible_ssh_private_key_file=devops_1.pem ansible_ssh_common_args="-o StrictHostKeyChecking=no"
                        EOF
                        
                        echo "✅ hosts.ini created successfully from NGINX_IP.txt and K8S_IP.txt"
                        cat hosts.ini
                        scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem -r ${WORKSPACE}/Devops_project2_chatApp/k8s-admin-setup ec2-user@${K8S_IP}:/home/ec2-user/
                        scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ${WORKSPACE}/TAG.txt ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup
                        scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem ${WORKSPACE}/NGINX_IP.txt ${WORKSPACE}/K8S_IP.txt ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup
            '''
                }
            }
        }
        stage('Ansible') {
            steps {
                script {
                    dir('k8s-admin-setup'){
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
        }
        stage('K8s-workstation -> NGINX') {
            steps {
                script {
                    dir('k8s-admin-setup'){
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'

echo "Connected to K8s workstation"
cd /home/ec2-user/k8s-admin-setup
chmod +x service_info.sh
./generate_service_info.sh
ENDSSH

                            scp -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup/SVC_DNS.txt .
                            scp -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup/SVC_PORT.txt .
                            scp -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${K8S_IP}:/home/ec2-user/k8s-admin-setup/SVC_*.txt .


                            scp -o StrictHostKeyChecking=no -i devops_1.pem SVC_DNS.txt SVC_PORT.txt nginx-conf.sh ec2-user@${NGINX_IP}:/home/ec2-user/
                            ssh -o StrictHostKeyChecking=no -i devops_1.pem ec2-user@${NGINX_IP} <<'ENDSSH'

echo "Inn NGINX server now!"
ls
chmod +x nginx-conf.sh
./nginx-conf.sh
sudo systemctl status nginx
ENDSSH
                 '''
                    }
                }
            }
        }
        
    }

    post {
        success {
            archiveArtifacts artifacts: 'TAG.txt, K8S_IP.txt, NGINX_IP.txt', fingerprint: true // UPDATED
            echo "Artifacts archived for next build."
        }
        failure {
            echo "Build failed. Please check the logs."
        }
    }
}
