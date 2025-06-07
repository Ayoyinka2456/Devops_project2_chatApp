#!/bin/bash

AWS_DEFAULT_REGION="us-east-2"
cluster_name="chatapp-cluster"
deployment_name="chatapp-deployment"


if eksctl get cluster --region "${AWS_DEFAULT_REGION}" --name "${cluster_name}" >/dev/null 2>&1; then
  echo "✅ Cluster already exists, skipping creation."
else
  echo "🚀 Creating new EKS cluster..."
  eksctl create cluster \
      --name "${cluster_name}" \
      --version 1.30 \
      --region "${AWS_DEFAULT_REGION}" \
      --nodegroup-name chatapp-workers \
      --node-type t2.micro \
      --nodes 3 \
      --nodes-min 1 \
      --nodes-max 4 \
      --managed
  sleep 600
fi

aws eks update-kubeconfig --name "${cluster_name}" --region "${AWS_DEFAULT_REGION}"
sleep 120
