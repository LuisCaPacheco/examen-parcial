#!/bin/bash
set -eux
# Instala Docker y levanta la imagen :stable (ultima estable conocida)
dnf update -y
dnf install -y docker nginx
systemctl enable --now docker
systemctl enable --now nginx

ECR_URL="${ecr_url}"
APP_PORT="${app_port}"

aws ecr get-login-password --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo us-east-1) | docker login --username AWS --password-stdin "$ECR_URL" || true

# Nginx como reverse proxy :80 -> :8080 (URL publica simple)
cat > /etc/nginx/conf.d/app.conf <<NGINX
server {
  listen 80;
  location / {
    proxy_pass http://127.0.0.1:${app_port};
    proxy_set_header Host \$host;
  }
}
NGINX
nginx -t && systemctl reload nginx || systemctl restart nginx

# Intenta traer :stable; si no existe aun, queda nginx 502 hasta primer deploy del workflow
docker pull "$ECR_URL:stable" || true
docker rm -f app || true
docker run -d --name app --restart unless-stopped -p ${app_port}:8080 -e APP_VERSION=stable "$ECR_URL:stable" || true
