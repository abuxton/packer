#!/usr/bin/env bash
# setup-tfe-mirror.sh
# Installs Docker CE, authenticates to the HashiCorp container registry,
# pulls the Terraform Enterprise image, and stores it in a local Docker
# Registry v2 instance served on localhost:5000 at boot via systemd.
#
# Required environment variables (set by Packer):
#   TFE_VERSION  — TFE image tag, e.g. "v202506-1"
#
# Required file (uploaded by Packer, deleted by this script):
#   /tmp/tfe.hclic  — HashiCorp Terraform Enterprise license

set -euo pipefail

TFE_IMAGE="images.releases.hashicorp.com/hashicorp/terraform-enterprise:${TFE_VERSION}"
LOCAL_TAG="localhost:5000/hashicorp/terraform-enterprise:${TFE_VERSION}"

echo "==> Waiting for cloud-init to complete..."
sudo cloud-init status --wait || true

# ---------------------------------------------------------------------------
# Install Docker CE
# ---------------------------------------------------------------------------
echo "==> Installing Docker CE..."
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

echo "==> Starting Docker service..."
sudo systemctl start docker

# ---------------------------------------------------------------------------
# Configure Docker to trust the local registry (insecure on localhost)
# ---------------------------------------------------------------------------
echo "==> Configuring Docker daemon for local registry..."
sudo tee /etc/docker/daemon.json > /dev/null << 'DAEMON'
{
  "insecure-registries": ["localhost:5000"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DAEMON

sudo systemctl restart docker

# ---------------------------------------------------------------------------
# Start a seed registry to receive the TFE image
# ---------------------------------------------------------------------------
echo "==> Pulling registry:2 image..."
sudo docker pull registry:2

echo "==> Creating registry data directory..."
sudo mkdir -p /var/lib/registry

echo "==> Starting seed registry on localhost:5000..."
sudo docker run -d \
  --name tfe-registry-seed \
  -p 5000:5000 \
  -v /var/lib/registry:/var/lib/registry \
  registry:2

echo "==> Waiting for seed registry to become ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "  Seed registry is ready."
    break
  fi
  echo "  Waiting... (${i}/30)"
  sleep 2
done

# ---------------------------------------------------------------------------
# Authenticate, pull TFE image, push to local registry, then clean up creds
# ---------------------------------------------------------------------------
echo "==> Logging in to HashiCorp container registry..."
sudo docker login --username terraform images.releases.hashicorp.com --password-stdin < /tmp/tfe.hclic

echo "==> Pulling Terraform Enterprise image: ${TFE_IMAGE}..."
sudo docker pull "${TFE_IMAGE}"

echo "==> Tagging image for local registry..."
sudo docker tag "${TFE_IMAGE}" "${LOCAL_TAG}"

echo "==> Pushing image to local registry..."
sudo docker push "${LOCAL_TAG}"

echo "==> Logging out and removing credentials..."
sudo docker logout images.releases.hashicorp.com
sudo rm -f /root/.docker/config.json
sudo rm -f /tmp/tfe.hclic

# Also clean up the pulled source image layers (only local copy needed)
sudo docker rmi "${TFE_IMAGE}" || true

# ---------------------------------------------------------------------------
# Stop seed registry; set up persistent systemd service
# ---------------------------------------------------------------------------
echo "==> Stopping seed registry..."
sudo docker stop tfe-registry-seed
sudo docker rm tfe-registry-seed

echo "==> Creating systemd service for persistent local registry..."
sudo tee /etc/systemd/system/tfe-local-registry.service > /dev/null << 'SERVICE'
[Unit]
Description=Local Docker Registry (Terraform Enterprise mirror)
Documentation=https://docs.docker.com/registry/
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop tfe-local-registry
ExecStartPre=-/usr/bin/docker rm tfe-local-registry
ExecStart=/usr/bin/docker run \
    --name tfe-local-registry \
    --publish 5000:5000 \
    --volume /var/lib/registry:/var/lib/registry \
    registry:2
ExecStop=/usr/bin/docker stop tfe-local-registry

[Install]
WantedBy=multi-user.target
SERVICE

echo "==> Enabling services to start on boot..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable tfe-local-registry

echo "==> Starting persistent local registry..."
sudo systemctl start tfe-local-registry

echo "==> Waiting for persistent registry to become ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "  Persistent registry is ready."
    break
  fi
  echo "  Waiting... (${i}/30)"
  sleep 2
done

# ---------------------------------------------------------------------------
# Verify the image is accessible in the local registry
# ---------------------------------------------------------------------------
echo "==> Verifying TFE image is available in local registry..."
curl -sf "http://localhost:5000/v2/hashicorp/terraform-enterprise/tags/list" \
  | grep -q "${TFE_VERSION}" \
  && echo "  Image 'hashicorp/terraform-enterprise:${TFE_VERSION}' found in local registry." \
  || echo "  WARNING: Could not verify image in local registry via tags API."

echo "==> TFE local mirror setup complete."
echo "    TFE image        : ${LOCAL_TAG}"
echo "    Registry address : http://localhost:5000"
echo "    Registry data    : /var/lib/registry"
