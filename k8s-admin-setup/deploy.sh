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
# echo "Getting Service DNS and Port"
# chmod +x service_info.sh
# ./service_info.sh

echo "🔍 Getting service DNS and port..."

# Extract DNS
SVC_DNS=$(kubectl get svc chatapp-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo "$SVC_DNS" > SVC_DNS.txt

# Extract Port
SVC_PORT=$(kubectl get svc chatapp-service -o jsonpath="{.spec.ports[0].port}")
echo "$SVC_PORT" > SVC_PORT.txt

# Save both to a single file too, if needed
echo "${SVC_DNS}:${SVC_PORT}" > external-ip.txt
# Fix permissions
chown ec2-user:ec2-user SVC_DNS.txt SVC_PORT.txt external-ip.txt
echo "✅ Saved DNS to SVC_DNS.txt and Port to SVC_PORT.txt"

