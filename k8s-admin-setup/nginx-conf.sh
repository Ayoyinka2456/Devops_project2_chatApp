
#!/bin/bash

# Read DNS and port values
SVC_DNS=$(cat /home/ec2-user/SVC_DNS.txt | xargs)
SVC_PORT=$(cat /home/ec2-user/SVC_PORT.txt | xargs)

echo "🔧 Updating /etc/nginx/nginx.conf with:"
echo "  Host: $SVC_DNS"
echo "  Port: $SVC_PORT"

# Backup current nginx.conf
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# Replace nginx.conf entirely (or append as needed)
sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    upstream myapp {
        server ${SVC_DNS}:${SVC_PORT};
    }

    server {
        listen ${SVC_PORT};

        location / {
            proxy_pass http://myapp;
        }
    }
}
EOF

# Test and reload
sudo nginx -t && sudo systemctl restart nginx
echo "✅ NGINX configuration updated and reloaded."
