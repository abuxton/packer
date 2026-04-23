#!/usr/bin/env bash
# setup-tfc-agent.sh
# Pre-pulls the HCP Terraform agent image through the local registry mirror so
# it is available for fast local pulls, and installs an opt-in systemd service.

set -euo pipefail

# Pin the agent version; update to a newer release when required.
TFC_AGENT_VERSION="${TFC_AGENT_VERSION:-1.22.0}"
TFC_AGENT_IMAGE="hashicorp/tfc-agent:${TFC_AGENT_VERSION}"
TFC_AGENT_ENV_FILE="/etc/tfc-agent/env"
TFC_AGENT_DATA_DIR="/var/lib/tfc-agent"

echo "============================================================================"
echo "HCP Terraform Agent Setup"
echo "============================================================================"

echo "==> Waiting for Docker registry mirror to be ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "    Registry mirror is ready."
    break
  fi
  echo "    Waiting... (${i}/30)"
  sleep 2
done

echo "==> Pre-pulling HCP Terraform agent image (${TFC_AGENT_IMAGE}) through local mirror..."
sudo docker pull --platform linux/amd64 "${TFC_AGENT_IMAGE}"

echo "==> Verifying image is accessible via the registry mirror..."
# A successful tags/list response confirms the image was seeded in the mirror.
if curl -sf "http://localhost:5000/v2/hashicorp/tfc-agent/tags/list" > /dev/null 2>&1; then
  echo "    Image confirmed in registry mirror."
else
  echo "    WARNING: Could not confirm image in mirror via v2 API (may still be cached by Docker)."
fi

echo "==> Creating tfc-agent directories..."
sudo mkdir -p /etc/tfc-agent "${TFC_AGENT_DATA_DIR}"

echo "==> Creating tfc-agent environment file template..."
# Quoted delimiter preserves literal content with no variable expansion.
sudo tee "${TFC_AGENT_ENV_FILE}.example" > /dev/null << 'ENV_TEMPLATE'
# HCP Terraform Agent configuration
# Copy this file to /etc/tfc-agent/env, fill in the token, then restrict perms.
#
# Usage:
#   sudo cp /etc/tfc-agent/env.example /etc/tfc-agent/env
#   sudo chmod 600 /etc/tfc-agent/env
#   sudo vi /etc/tfc-agent/env          # set TFC_AGENT_TOKEN
#   sudo systemctl enable --now tfc-agent

# Required: token from your HCP Terraform agent pool
TFC_AGENT_TOKEN=your-agent-token-here

# Optional: human-readable name shown in the HCP Terraform UI
TFC_AGENT_NAME=

# Optional: 'minor' (default), 'patch', or 'disabled'
TFC_AGENT_AUTO_UPDATE=minor
ENV_TEMPLATE

sudo chmod 644 "${TFC_AGENT_ENV_FILE}.example"

echo "==> Installing systemd service for HCP Terraform agent (disabled by default)..."
# Unquoted delimiter so ${TFC_AGENT_VERSION} is expanded into the unit file.
# ExecStart is a single line to avoid heredoc backslash-newline consumption.
sudo tee /etc/systemd/system/tfc-agent.service > /dev/null << SERVICE
[Unit]
Description=HCP Terraform Agent
Documentation=https://developer.hashicorp.com/terraform/cloud-docs/agents
After=docker.service docker-registry-mirror.service
Requires=docker.service
ConditionPathExists=/etc/tfc-agent/env

[Service]
EnvironmentFile=/etc/tfc-agent/env
TimeoutStartSec=0
Restart=on-failure
RestartSec=10
ExecStartPre=-/usr/bin/docker stop tfc-agent
ExecStartPre=-/usr/bin/docker rm tfc-agent
ExecStart=/usr/bin/docker run --name tfc-agent --platform linux/amd64 --env TFC_AGENT_TOKEN --env TFC_AGENT_NAME --env TFC_AGENT_AUTO_UPDATE hashicorp/tfc-agent:${TFC_AGENT_VERSION}
ExecStop=/usr/bin/docker stop tfc-agent

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
# The service is intentionally NOT enabled here; operators opt in after
# configuring /etc/tfc-agent/env with a valid TFC_AGENT_TOKEN.

echo "============================================================================"
echo "HCP Terraform Agent Setup Complete"
echo "============================================================================"
echo ""
echo "  Image '${TFC_AGENT_IMAGE}' is now cached in the local registry mirror."
echo ""
echo "  To start the managed agent service:"
echo "    sudo cp /etc/tfc-agent/env.example /etc/tfc-agent/env"
echo "    sudo chmod 600 /etc/tfc-agent/env"
echo "    sudo vi /etc/tfc-agent/env            # set TFC_AGENT_TOKEN"
echo "    sudo systemctl enable --now tfc-agent"
echo ""
echo "  Or run the agent directly:"
echo "    export TFC_AGENT_TOKEN=<your-token>"
echo "    docker run --platform=linux/amd64 -e TFC_AGENT_TOKEN hashicorp/tfc-agent:${TFC_AGENT_VERSION}"
