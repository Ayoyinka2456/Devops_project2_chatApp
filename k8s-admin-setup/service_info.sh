
#!/bin/bash

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
