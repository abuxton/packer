#!/usr/bin/env bash
# setup-docker-mirror.sh
# Installs Docker and configures a Docker Registry v2 pull-through cache mirror
# that proxies Docker Hub requests and caches them locally.

set -euo pipefail

echo "==> Waiting for cloud-init to complete..."
sudo cloud-init status --wait || true

echo "==> Installing Docker..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Pulling registry:2 image..."
sudo docker pull registry:2

echo "==> Creating registry configuration for pull-through cache..."
sudo mkdir -p /etc/docker/registry /var/lib/registry

sudo tee /etc/docker/registry/config.yml > /dev/null << 'CONFIG'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
proxy:
  remoteurl: https://registry-1.docker.io
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
CONFIG

echo "==> Creating systemd service for Docker registry mirror..."
sudo tee /etc/systemd/system/docker-registry-mirror.service > /dev/null << 'SERVICE'
[Unit]
Description=Docker Registry Pull-Through Cache Mirror
Documentation=https://docs.docker.com/registry/
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop docker-registry-mirror
ExecStartPre=-/usr/bin/docker rm docker-registry-mirror
ExecStart=/usr/bin/docker run \
    --name docker-registry-mirror \
    --publish 5000:5000 \
    --volume /var/lib/registry:/var/lib/registry \
    --volume /etc/docker/registry/config.yml:/etc/docker/registry/config.yml:ro \
    registry:2
ExecStop=/usr/bin/docker stop docker-registry-mirror

[Install]
WantedBy=multi-user.target
SERVICE

echo "==> Configuring Docker daemon to use local mirror..."
sudo tee /etc/docker/daemon.json > /dev/null << 'DAEMON'
{
  "registry-mirrors": ["http://localhost:5000"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DAEMON

echo "==> Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable docker-registry-mirror
sudo systemctl restart docker
sudo systemctl start docker-registry-mirror

echo "==> Waiting for registry mirror to become ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "Registry mirror is ready."
    break
  fi
  echo "  Waiting... (${i}/30)"
  sleep 2
done

echo "==> Verifying Docker and registry mirror..."
sudo docker info | grep -i "registry mirrors" || true
curl -sf http://localhost:5000/v2/ && echo "Registry mirror endpoint OK"

echo "==> Docker registry mirror setup complete."
