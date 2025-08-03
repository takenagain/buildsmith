#!/bin/bash
# Proxmox LXC deployment script for n8n (Ubuntu 24.04 LTS)
# Resources: 4 vCPU, 8192 MB RAM, 80 GB disk (adjustable)

set -euo pipefail
trap 'echo "❌ Script failed at line $LINENO." >&2; exit 1' ERR

### 1. Define variables ###
# Allow CTID to be provided as an argument or environment variable
CTID="${1:-${CTID:-}}"
if [ -z "$CTID" ]; then
    echo "Detecting next available container ID..."
    CTID=$(pvesh get /cluster/nextid) || { echo "Failed to determine next container ID" >&2; exit 1; }
fi

# Ensure the chosen CTID is not already in use
existing_ids=$( {
    pct list | awk 'NR>1 {print $1}'
    qm list | awk 'NR>1 {print $1}'
} )
if echo "$existing_ids" | grep -qw "$CTID"; then
    echo "Container ID $CTID is already in use." >&2
    exit 1
fi

HOSTNAME="n8n-server"         # Container hostname
CORES=4                       # vCPU cores for the container
MEMORY=8192                   # RAM in MB for the container
DISK_SIZE=80                  # Disk size in GB for container rootfs
TEMPLATE_BASE="ubuntu-24.04-standard"  # Base name for Ubuntu 24.04 LTS template
STORAGE_POOL="local-lvm"      # Proxmox storage pool for the container

### 2. Download Ubuntu 24.04 LXC template if not already available ###
pveam update
TEMPLATE_FULL=$(pveam available --section system | awk -v tmpl="$TEMPLATE_BASE" '$2 ~ tmpl {print $2; exit}')
if [ -z "$TEMPLATE_FULL" ]; then
    echo "Template $TEMPLATE_BASE not found in pveam list" >&2
    exit 1
fi
if ! pveam list local | awk '{print $2}' | grep -qw "$TEMPLATE_FULL"; then
    echo "Downloading LXC template $TEMPLATE_FULL..."
    pveam download local "$TEMPLATE_FULL"
fi

### 3. Create the LXC container ###
echo "Creating LXC container $CTID ($HOSTNAME)..."
pct create "$CTID" "local:vztmpl/$TEMPLATE_FULL" -hostname "$HOSTNAME" \
    -cores "$CORES" -memory "$MEMORY" -rootfs "$STORAGE_POOL:$DISK_SIZE" \
    -net0 name=eth0,bridge=vmbr0,ip=dhcp -unprivileged 1 -features nesting=1,keyctl=1

### 4. Start the container ###
pct start "$CTID"
echo "Container $CTID started. Installing n8n and dependencies..."

### 5. Update apt and install Node.js (v18 LTS) & build tools inside container ###
pct exec "$CTID" -- apt-get update
pct exec "$CTID" -- apt-get upgrade -y
pct exec "$CTID" -- apt-get install -y curl gnupg build-essential
pct exec "$CTID" -- bash -c "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -"
pct exec "$CTID" -- apt-get install -y nodejs

### 6. Install n8n globally using npm ###
pct exec "$CTID" -- npm install -g n8n

### 7. Create a dedicated n8n user ###
pct exec "$CTID" -- useradd -m -s /usr/sbin/nologin n8n

### 8. Prepare environment file for API keys (placeholders for now) ###
pct exec "$CTID" -- bash -c "echo 'OPENAI_API_KEY=\"YOUR_OPENAI_API_KEY\"' > /etc/n8n.env"
pct exec "$CTID" -- bash -c "echo 'ANTHROPIC_API_KEY=\"YOUR_ANTHROPIC_API_KEY\"' >> /etc/n8n.env"
pct exec "$CTID" -- bash -c "chmod 600 /etc/n8n.env"
pct exec "$CTID" -- bash -c "chown n8n:n8n /etc/n8n.env"

### 9. Create systemd service for n8n ###
pct exec "$CTID" -- bash -c "cat >/etc/systemd/system/n8n.service <<'SERVICE'
[Unit]
Description=n8n Automation Service
After=network.target

[Service]
Type=simple
User=n8n
EnvironmentFile=/etc/n8n.env
ExecStart=/usr/bin/n8n
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE"

### 10. Enable and start the n8n service ###
pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl enable n8n.service
pct exec "$CTID" -- systemctl start n8n.service

# Ensure the service is running before reporting success
if ! pct exec "$CTID" -- systemctl is-active --quiet n8n.service; then
    echo "Failed to verify n8n service is running" >&2
    exit 1
fi

# Fetch the container's IP address for the final message
if ! CONTAINER_IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}'); then
    echo "Failed to determine container IP address" >&2
    exit 1
fi
if [ -z "$CONTAINER_IP" ]; then
    echo "Container IP address is empty" >&2
    exit 1
fi
echo "✅ n8n installation complete!"
echo "Open http://$CONTAINER_IP:5678 in your browser to finish setup."
echo "On first visit you'll be prompted to create an n8n account; there are no default credentials."
