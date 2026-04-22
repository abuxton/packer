#!/usr/bin/env bash
# setup-docker-local.sh
# Installs Docker, starts a local Docker Registry, pre-loads a specified
# container image into it, and configures the Docker daemon to use the local
# registry as a mirror so the image is served without internet access.
#
# Required environment variable:
#   CONTAINER_IMAGE  - image to pre-load (e.g. "nginx:latest")

set -euo pipefail

CONTAINER_IMAGE="${CONTAINER_IMAGE:-nginx:latest}"

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

echo "==> Creating registry data directory..."
sudo mkdir -p /var/lib/registry

echo "==> Starting a temporary local registry to pre-seed the image..."
sudo docker run -d \
  --name local-registry-seed \
  -p 5000:5000 \
  -v /var/lib/registry:/var/lib/registry \
  registry:2

echo "==> Waiting for the temporary registry to become ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "  Registry is ready."
    break
  fi
  echo "  Waiting... (${i}/30)"
  sleep 2
done

echo "==> Pulling container image from Docker Hub: ${CONTAINER_IMAGE}..."
sudo docker pull "${CONTAINER_IMAGE}"

echo "==> Tagging and pushing image to local registry..."
# Normalize image name for the local registry:
#   official images (no slash) → library/<name>
#   e.g. nginx:latest → localhost:5000/library/nginx:latest
#   e.g. myorg/myapp:1.0 → localhost:5000/myorg/myapp:1.0
if [[ "${CONTAINER_IMAGE}" != */* ]]; then
  LOCAL_TAG="localhost:5000/library/${CONTAINER_IMAGE}"
else
  LOCAL_TAG="localhost:5000/${CONTAINER_IMAGE}"
fi

sudo docker tag "${CONTAINER_IMAGE}" "${LOCAL_TAG}"
sudo docker push "${LOCAL_TAG}"

echo "==> Removing the seed registry container (data persists on disk)..."
sudo docker stop local-registry-seed
sudo docker rm local-registry-seed

echo "==> Creating systemd service for the local Docker registry..."
sudo tee /etc/systemd/system/docker-local-registry.service > /dev/null << 'SERVICE'
[Unit]
Description=Local Docker Registry (pre-seeded container images)
Documentation=https://docs.docker.com/registry/
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop docker-local-registry
ExecStartPre=-/usr/bin/docker rm docker-local-registry
ExecStart=/usr/bin/docker run \
    --name docker-local-registry \
    --publish 5000:5000 \
    --volume /var/lib/registry:/var/lib/registry \
    registry:2
ExecStop=/usr/bin/docker stop docker-local-registry

[Install]
WantedBy=multi-user.target
SERVICE

echo "==> Configuring Docker daemon to use local registry as mirror..."
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

echo "==> Enabling services to start on boot..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable docker-local-registry

echo "==> Starting the persistent local registry..."
sudo systemctl start docker-local-registry

echo "==> Waiting for the persistent registry to become ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "  Persistent registry is ready."
    break
  fi
  echo "  Waiting... (${i}/30)"
  sleep 2
done

echo "==> Verifying the pre-seeded image is available in the local registry..."
if [[ "${CONTAINER_IMAGE}" != */* ]]; then
  IMAGE_NAME="${CONTAINER_IMAGE%%:*}"
  IMAGE_TAG="${CONTAINER_IMAGE##*:}"
  curl -sf "http://localhost:5000/v2/library/${IMAGE_NAME}/tags/list" \
    | grep -q "${IMAGE_TAG}" \
    && echo "  Image 'library/${CONTAINER_IMAGE}' found in local registry." \
    || echo "  WARNING: Could not verify image in registry."
else
  REPO="${CONTAINER_IMAGE%%:*}"
  TAG="${CONTAINER_IMAGE##*:}"
  curl -sf "http://localhost:5000/v2/${REPO}/tags/list" \
    | grep -q "${TAG}" \
    && echo "  Image '${CONTAINER_IMAGE}' found in local registry." \
    || echo "  WARNING: Could not verify image in registry."
fi

echo "==> Local Docker registry setup complete."
echo "    Pre-loaded image : ${CONTAINER_IMAGE}"
echo "    Registry address : http://localhost:5000"
echo "    Registry data    : /var/lib/registry"
