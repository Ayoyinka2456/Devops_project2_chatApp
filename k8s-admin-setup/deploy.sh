#!/bin/bash

cd /home/ec2-user/k8s-admin-setup/

# Fail early if any required file is missing
for f in TAG.txt K8S_IP.txt NGINX_IP.txt; do
    [ ! -f "$f" ] && echo "❌ $f not found!" && exit 1
done

export TAG=$(cat TAG.txt | tr -d '[:space:]')
export K8S_IP=$(cat K8S_IP.txt | tr -d '[:space:]')
export NGINX_IP=$(cat NGINX_IP.txt | tr -d '[:space:]')

echo "✅ TAG=$TAG"
echo "✅ K8S_IP=$K8S_IP"
echo "✅ NGINX_IP=$NGINX_IP"

python3 render.py
sudo chown ec2-user:ec2-user deployment.yml
echo "Deploying pods"
kubectl apply -f deployment.yml
sleep 300
echo "Getting Service DNS and Port"
chmod +x service_info.sh
./service_info.sh
