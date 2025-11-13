# Open WebUI + LiteLLM Setup Guide (Linux/Ubuntu)

> **📌 Note:** This repository now supports **Azure Container Apps** as the primary deployment method using Azure Developer CLI (azd).
> - For Azure deployment: See [README.md](README.md) and [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)
> - For local Docker development: See [SETUP-LOCAL.md](SETUP-LOCAL.md)
> - This guide remains for reference for manual Linux server installations.

This guide walks through setting up Open WebUI with LiteLLM as a proxy to Azure AI Foundry on Ubuntu Linux.

## Prerequisites

- Ubuntu 20.04 or later (22.04 LTS recommended)
- Sudo access
- Network connectivity to Azure

## Section 1: System Updates

```bash
sudo apt update
sudo apt upgrade -y
```

## Section 2: Install Docker

```bash
# Install Docker using the official convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group (requires logout/login or newgrp to take effect)
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker installation
docker --version
docker compose version
```

**Important:** Log out and log back in for the group membership to take effect:

```bash
exit
```

Then SSH back in and verify Docker works without sudo:

```bash
docker --version
docker compose version
```

## Section 3: Configure SSH Key Authentication (Optional but Recommended)

Set up key-based SSH authentication for passwordless login from your laptop.

**From your Windows laptop:**

```powershell
# Copy your SSH public key to the server (use Ed25519 if you have it, otherwise RSA)
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <username>@<server-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Test passwordless login:

```powershell
ssh <username>@<server-ip>
```

**Add to Windows Terminal (Optional):**

Open Windows Terminal settings (Ctrl+,) and add a new profile:
- Name: `Ubuntu Docker Server` (or similar)
- Command line: `ssh <username>@<server-ip>`
- Save

## Section 4: Configure Remote Docker Context (Optional)

If you want to manage Docker from your Windows laptop instead of SSH'ing into the server:

**From your Windows laptop:**

```powershell
# Create a Docker context pointing to your Ubuntu server
docker context create ubuntu-server --docker "host=ssh://<username>@<server-ip>"

# Switch to the new context
docker context use ubuntu-server

# Verify it works
docker ps
```

Now you can run `docker compose up -d` from your laptop and it will deploy to the Ubuntu server.

## Section 5: Clone Repository and Configure

**Option A: Work directly on the server (via SSH)**

```bash
cd ~
git clone https://github.com/your-username/openwebui-litellm.git
cd openwebui-litellm
```

**Option B: Work from your laptop with Docker context (recommended)**

Keep your repository on your laptop and use the remote Docker context configured in Section 4. No need to clone on the server - just work from your local repo:

```powershell
# On your laptop in your repo directory
cd C:\path\to\your\repo
docker compose up -d  # Deploys to Ubuntu server via SSH context
```

## Section 6: Configure Environment Variables

Ensure you have a `.env` file in your repository with your Azure credentials:

```env
# Azure AI Foundry Configuration
AZURE_API_KEY=your-azure-api-key-here
AZURE_API_BASE=https://your-azure-endpoint.openai.azure.com/
AZURE_API_VERSION=2024-02-15-preview

# LiteLLM Master Key (generate a secure random key)
LITELLM_MASTER_KEY=sk-your-secure-random-key-here
```

### Generate a Secure Master Key

**On Ubuntu/Linux:**
```bash
openssl rand -base64 36 | tr -d '\n' && echo
```

**On Windows PowerShell:**
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
```

Copy the generated key and use it as your `LITELLM_MASTER_KEY` value in your `.env` file.

## Section 7: Deploy with Docker Compose

**If working from laptop with Docker context:**

```powershell
# From your repo directory on Windows
docker compose up -d
```

**If working directly on server:**

```bash
cd ~/openwebui-litellm
docker compose up -d
```

Verify containers are running:

```bash
docker compose ps
docker compose logs -f
```

## Section 8: Configure Firewall (UFW)

Allow access to the Open WebUI port:

```bash
# Enable UFW if not already enabled
sudo ufw enable

# Allow SSH (important - don't lock yourself out!)
sudo ufw allow ssh

# Allow Open WebUI port
sudo ufw allow 3000/tcp

# Optional: Allow LiteLLM API port if needed
sudo ufw allow 4000/tcp

# Check status
sudo ufw status
```

## Section 9: Access Open WebUI

Open your browser and navigate to:

```
http://<server-ip>:3000
```

For example, if your Ubuntu server IP is `192.168.50.8`:

```
http://192.168.50.8:3000
```

Create your first user account and start chatting!

## Section 10: Enable Auto-Start on Boot

Docker Compose services will automatically start on boot if the Docker service is enabled (which we did in Section 2).

To verify:

```bash
sudo systemctl is-enabled docker
```

Should return `enabled`.

## Section 11: Managing the Services

```bash
# Stop services
docker compose down

# Restart services
docker compose restart

# View logs
docker compose logs -f open-webui
docker compose logs -f litellm

# Update containers
docker compose pull
docker compose up -d
```

## Troubleshooting

### Check Container Status
```bash
docker compose ps
docker compose logs
```

### Check Port Binding
```bash
sudo netstat -tlnp | grep :3000
sudo netstat -tlnp | grep :4000
```

### Check Docker Service
```bash
sudo systemctl status docker
```

### Test Network Connectivity
```bash
# From another machine
curl http://<server-ip>:3000
```

### Verify Environment Variables
```bash
docker compose config
```

## Security Recommendations

1. **Use Strong API Keys:** Generate cryptographically secure random keys for `LITELLM_MASTER_KEY`
2. **Restrict Firewall:** Only allow necessary ports and IP ranges
3. **Keep System Updated:** Regularly run `apt update && apt upgrade`
4. **Use SSH Keys:** Disable password authentication for SSH
5. **Monitor Logs:** Regularly check `docker compose logs` for issues
6. **Backup Configuration:** Keep `.env` and config files backed up securely

## Additional Configuration

### Using a Reverse Proxy (Optional)

For production deployments, consider using Nginx or Caddy as a reverse proxy with SSL/TLS:

```bash
# Example with Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Create Caddyfile
sudo nano /etc/caddy/Caddyfile
```

Example Caddyfile:
```
yourdomain.com {
    reverse_proxy localhost:3000
}
```

```bash
sudo systemctl restart caddy
```

### Custom Domain with DNS

1. Point your domain's A record to your server's public IP
2. Configure Caddy or Nginx with the domain name
3. Caddy will automatically obtain Let's Encrypt SSL certificates

## Summary

You now have Open WebUI running with LiteLLM as a proxy to Azure AI Foundry on native Linux. This setup is:

- ✅ Stable (no nested virtualization)
- ✅ High performance (native Docker)
- ✅ Auto-starts on boot
- ✅ Firewall protected
- ✅ Easy to manage with Docker Compose

Access your instance at `http://<server-ip>:3000` and start chatting!
