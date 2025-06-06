pipeline {
    agent {
        label 'Jenkins_Server'
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('docker_login')
        DOCKER_IMAGE = "${DOCKERHUB_CREDENTIALS_USR}/chatApp:1"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Cleaning workspace..."
                sh "whoami"
                sh "sudo rm -rf *"
                sh "ls && pwd"
                git branch: 'troubleshoot', url: 'https://github.com/Ayoyinka2456/Devops_project2_chatApp2_chatApp.git'
            }
        }

        stage('Restore Artifacts') { // UPDATED NAME
            steps {
                script {
                    echo "Restoring artifacts from previous successful build..."
                    copyArtifacts(
                        projectName: env.JOB_NAME,
                        selector: [$class: 'StatusBuildSelector', stable: true],
                        // filter: 'counter.txt, K8S_IP.txt', // UPDATED TO INCLUDE K8S_IP
                        filter: 'K8S_IP.txt', // UPDATED TO INCLUDE K8S_IP
                        optional: true
                    )
                }
            }
        }

        stage('Dockerize') {
            steps {
                script {
                    def imageTag = "${DOCKER_IMAGE}"
                    echo "Using Docker image tag: ${imageTag}"

                    sh "docker build -t ${imageTag} ."
                    sh "docker login -u \"${DOCKERHUB_CREDENTIALS_USR}\" -p \"${DOCKERHUB_CREDENTIALS_PSW}\""
                    sh "docker push ${imageTag}"
                }
            }
        }
        stage('Terraform') {
            agent {
                label 'Terraform'
            }
            steps {
                script {
                    // BEGIN ADDED CLEANUP BLOCK
                    if (fileExists('Devops_project2_chatApp/K8S_IP.txt')) {
                        env.K8S_IP = readFile('Devops_project2_chatApp/K8S_IP.txt').trim()
                        echo "Loaded previous K8S_IP: ${env.K8S_IP}"

                        sh '''
                            echo "Cleaning up previous K8s workstation..."
                            ssh -o StrictHostKeyChecking=no -i Devops_project2_chatApp/k8s-admin-setup/devops_1.pem ec2-user@${K8S_IP} <<'ENDSSH'
echo "Connected to K8s workstation"
if command -v kops &> /dev/null; then
    export KOPS_STATE_STORE=s3://chatApp-k8s-store
    kops delete cluster --name=chatApp.k8s.local --yes || true
    sleep 180
else
    echo "kops not found on remote instance."
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
                            sleep 60
                            cd ../ && rm -rf Devops_project2_chatApp
                            git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp2_chatApp.git
                            cd Devops_project2_chatApp2_chatApp
                        else
                            git clone -b troubleshoot https://github.com/Ayoyinka2456/Devops_project2_chatApp2_chatApp.git
                            cd Devops_project2_chatApp2_chatApp/
                        fi
                        terraform init
                        terraform apply -auto-approve
                        sleep 300

                        NGINX_IP=$(terraform output -raw NGINX_public_ip)
                        K8S_IP=$(terraform output -raw k8s_workstation_public_ip)

                        echo "$NGINX_IP" > NGINX_IP.txt
                        echo "$K8S_IP" > K8S_IP.txt
                        chmod 400 k8s-admin-setup/devops_1.pem

                        scp -o StrictHostKeyChecking=no -i k8s-admin-setup/devops_1.pem -r ${WORKSPACE}/Devops_project2_chatApp/k8s-admin-setup ec2-user@${NGINX_IP}:/home/ec2-user/

                        ssh -i "k8s-admin-setup/devops_1.pem" -o StrictHostKeyChecking=no ec2-user@${NGINX_IP} <<'ENDSSH'
sudo yum -y install epel-release
sudo yum -y install nginx
sudo systemctl start nginx
sudo systemctl enable nginx
cd /home/ec2-user/k8s-admin-setup/
chmod 400 devops_1.pem
ansible-playbook -i host.ini 01-* && \
sleep 30 && \
ansible-playbook -i host.ini 02-* && \
ansible-playbook -i host.ini 03-* && \
ansible-playbook -i host.ini 04-*
ENDSSH
                    '''
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'counter.txt, K8S_IP.txt, NGINX_IP.txt', fingerprint: true // UPDATED
            echo "Artifacts archived for next build."
        }
        failure {
            echo "Build failed. Please check the logs."
        }
    }
}
