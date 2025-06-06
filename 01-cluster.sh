#!/bin/bash

AWS_DEFAULT_REGION="us-east-2"
cluster_name="chatapp-cluster"
deployment_name="chatapp-deployment"

if command -v kubectl >/dev/null 2>&1; then
  echo "✅ kubectl found. Checking for existing deployment..."

  if kubectl get deployment "${deployment_name}" >/dev/null 2>&1; then
      echo "🗑️ Deleting existing deployment..."
      kubectl delete -f deployment.yml
      echo "⏳ Waiting for resources to fully terminate..."
      sleep 300
  else
      echo "  No existing deployment found. Skipping deletion and sleep."
  fi
else
  echo "  kubectl not installed. Skipping Kubernetes resource check and deletion."
fi

if command -v eksctl >/dev/null 2>&1; then
  echo "✅ eksctl found. Checking for existing EKS cluster..."

  if eksctl get cluster --name "${cluster_name}" --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1; then
      echo "🗑️ Cluster found. Deleting EKS cluster..."
      eksctl delete cluster --name "${cluster_name}" --region "${AWS_DEFAULT_REGION}"
      echo "⏳ Waiting for cluster deletion to complete..."
      sleep 600
  else
      echo "  No existing cluster found. Skipping deletion and sleep."
  fi
else
  echo "  eksctl not installed. Skipping EKS cluster deletion."
fi

if eksctl get cluster --region "${AWS_DEFAULT_REGION}" --name "${cluster_name}" >/dev/null 2>&1; then
  echo "✅ Cluster already exists, skipping creation."
else
  echo "🚀 Creating new EKS cluster..."
  eksctl create cluster \
      --name "${cluster_name}" \
      --version 1.30 \
      --region "${AWS_DEFAULT_REGION}" \
      --nodegroup-name chatApp-workers \
      --node-type t2.micro \
      --nodes 3 \
      --nodes-min 1 \
      --nodes-max 4 \
      --managed
  sleep 600
fi

aws eks update-kubeconfig --name "${cluster_name}" --region "${AWS_DEFAULT_REGION}"
sleep 120

kubectl apply -f deployment.yml
sleep 180
kubectl get all -o wide
echo "$(kubectl get svc chatapp-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"):$(kubectl get svc chatapp-service -o jsonpath="{.spec.ports[0].port}")" > external-ip.txt

SVC_DNS=$(kubectl get svc chatapp-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo "🔗 chatApp is available at: http://${SVC_DNS}:3000"
