# Open WebUI + LiteLLM Setup on Windows Server 2022 with WSL2

> **📌 Note:** This repository now supports **Azure Container Apps** as the primary deployment method using Azure Developer CLI (azd).
> - For Azure deployment: See [README.md](README.md) and [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)
> - For local Docker development: See [SETUP-LOCAL.md](SETUP-LOCAL.md)
> - This guide remains for reference for manual Windows Server installations.

This document outlines the complete setup process for running Open WebUI and LiteLLM in Docker on WSL2, accessible via Windows Server 2022.

## Prerequisites
- Windows Server 2022 (Domain Controller)
- PowerShell with Administrator access

## 1. WSL2 Installation

### Install WSL2

**Run as Administrator:**
```powershell
# Enable WSL feature
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine Platform
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Reboot required
Restart-Computer
```

**After reboot, set WSL 2 as default:**
```powershell
wsl --set-default-version 2
```

### Install Ubuntu Distribution

```powershell
# Install Ubuntu from Microsoft Store or via command
wsl --install -d Ubuntu

# Or list available distributions
wsl --list --online

# Install specific version
wsl --install -d Ubuntu-22.04
```

**First Launch:**
When you first run `wsl`, you'll be prompted to:
1. Create a username (recommend using `dockeruser` to match this guide)
2. Set a password

### Verify Installation

```powershell
# Check WSL version
wsl --version

# List installed distributions
wsl -l -v

# Verify WSL 2 is being used
# Output should show VERSION 2
```

## 2. Docker Installation in WSL2

### Install Docker in Ubuntu WSL

**Open WSL as dockeruser:**
```bash
# Update package list
sudo apt update

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group (avoid needing sudo)
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start

# Enable Docker to start on WSL launch
echo "sudo service docker start" >> ~/.bashrc
```

**Exit and restart WSL for group membership to take effect:**
```bash
exit
```

Then restart WSL:
```powershell
wsl
```

**Test Docker installation:**
```bash
docker --version
docker compose version
docker run hello-world
```

### Create docker.bat for Windows Access

To run Docker commands from Windows PowerShell/CMD (not just inside WSL):

**Create `C:\Windows\System32\docker.bat` (as Administrator):**
```batch
@echo off
wsl docker %*
```

**Verify it works from Windows:**
```powershell
docker --version
docker ps
```

## 3. SSH Configuration

### Initial Setup
1. Configured SSH server on Windows Server 2022
2. Started with password authentication
3. Switched to SSH key-based authentication for security

### SSH Access
- Connect as `dockeruser`: `ssh dockeruser@server-ip`
- Used for all Docker operations

## 2. WSL2 and Docker Setup

### Docker in WSL2
1. Installed Docker in WSL2 (Ubuntu distribution)
2. Created `C:\Windows\System32\docker.bat` to allow Docker commands from Windows CMD/PowerShell:
   ```batch
   @echo off
   wsl docker %*
   ```

### Docker Context for Remote Access
1. On local machine, added remote Docker context:
   ```powershell
   docker context create lab --docker "host=ssh://dockeruser@server-ip"
   docker context use lab
   ```
2. This allows running `docker` and `docker compose` commands from local machine that execute on the remote server

## 3. Open WebUI and LiteLLM Configuration

### Project Structure
```
openwebui-litellm/
├── docker-compose.yml
├── litellm-config.yaml
├── .env
└── .env.template
```

### Environment Variables (`.env`)
```env
# Azure AI Foundry Configuration
AZURE_API_KEY=<your-azure-api-key>
AZURE_API_BASE=https://<your-project>.openai.azure.com/
AZURE_API_VERSION=2025-01-01-preview

# LiteLLM Master Key (generated secure random key)
LITELLM_MASTER_KEY=sk-<48-character-random-string>
```

**Key Generation:**
Generated secure API key using PowerShell:
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
```

### Docker Compose Configuration

**Key Feature: Embedded Config**
To work with remote Docker contexts over SSH, the `litellm-config.yaml` is embedded directly in `docker-compose.yml` using Docker configs instead of volume mounts. This avoids Windows/WSL path issues.

**docker-compose.yml highlights:**
- Removed obsolete `version` attribute
- LiteLLM uses embedded Docker config (not file mount)
- Environment variables loaded from `.env` file
- Both services on custom bridge network
- Open WebUI configured to use LiteLLM proxy

### Services
- **LiteLLM**: Proxy to Azure AI Foundry models (port 4000)
- **Open WebUI**: Web interface for chat (port 3000)

## 4. WSL2 Auto-Start Configuration

### Problem
WSL2 automatically shuts down when idle, stopping Docker containers.

### Solution: Scheduled Task

Created a Windows scheduled task that keeps WSL2 running by executing a minimal command as dockeruser at system startup.

**Commands (as Administrator):**
```powershell
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "--exec dbus-launch true"
$trigger = New-ScheduledTaskTrigger -AtStartup
$credential = Get-Credential -UserName "lab\dockeruser"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "KeepDockerUserWSLAlive" -Action $action -Trigger $trigger -User $credential.UserName -Password $credential.GetNetworkCredential().Password -Settings $settings
```

**Group Policy Requirements (Domain Controller):**
Since this is a Domain Controller, user rights are managed via Group Policy:
1. Open `gpmc.msc` (Group Policy Management)
2. Edit: Default Domain Controllers Policy
3. Navigate to: Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → User Rights Assignment
4. Add `dockeruser` to:
   - **Log on as a batch job** (required for scheduled tasks)
   - **Allow log on locally** (required for testing with `runas`)
5. Run `gpupdate /force` to apply changes

**Verification:**
After reboot, Docker containers auto-start and persist with WSL2 running continuously.

## 5. Network Access Configuration

### WSL2 Port Forwarding Setup

**Problem:**
WSL2 runs in a Hyper-V VM with its own network. Docker containers inside WSL2 are not directly accessible from outside the Windows host.

**Solution: Windows Port Proxy**

Port proxy forwards connections from Windows to the WSL2 network where Docker is running.

**Critical: Use dockeruser's WSL IP**
Since Docker runs in dockeruser's WSL instance, you must use dockeruser's WSL IP address, not Administrator's. WSL instances are per-user.

**Get dockeruser's WSL IP:**
```cmd
# As dockeruser (via SSH or runas)
wsl hostname -I
# Use the FIRST IP address (e.g., 172.24.64.204)
# Ignore 172.17.0.1 and 172.18.0.1 (Docker bridge networks)
```

**Configure Port Proxy (as Administrator):**
```powershell
# Remove any existing port proxies for port 3000
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3000

# Add port proxy to dockeruser's WSL instance
# Replace 172.24.64.204 with the IP from dockeruser's "wsl hostname -I"
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3000 connectaddress=172.24.64.204 connectport=3000

# Verify
netsh interface portproxy show all
```

**Windows Firewall:**
```powershell
# Allow inbound connections on port 3000
New-NetFirewallRule -DisplayName "Open WebUI Direct" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### Access
- **Open WebUI**: `http://server-ip:3000`
- **LiteLLM API**: `http://server-ip:4000` (add firewall rule and portproxy if needed)

### Important Notes
- **WSL IP addresses can change on reboot** - The port proxy will need to be updated if the WSL IP changes
- See section 6 below for making this persistent across reboots

## 6. Making Port Proxy Persistent Across Reboots

**Problem:**
WSL2 IP addresses can change on reboot, breaking the port proxy configuration.

**Solution: Scheduled Task to Update Port Proxy**

Create a scheduled task that runs at startup and updates the port proxy with the current WSL IP.

**Create the script (as Administrator):**
```powershell
# Create Scripts directory
New-Item -ItemType Directory -Path C:\Scripts -Force

# Create the port forwarding script
@'
# Get dockeruser's WSL IP address
$wslIp = (wsl -u dockeruser hostname -I).Split()[0]

# Remove old port proxies
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3000 | Out-Null
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=4000 | Out-Null

# Add new port proxies with current WSL IP
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3000 connectaddress=$wslIp connectport=3000
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=4000 connectaddress=$wslIp connectport=4000

# Log the configuration
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Configured port forwarding to dockeruser WSL IP: $wslIp" | Out-File -Append C:\Scripts\portforward.log
'@ | Out-File -FilePath C:\Scripts\WSL-PortForward.ps1 -Encoding UTF8
```

**Create scheduled task (as Administrator):**
```powershell
# Create task action
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\WSL-PortForward.ps1"

# Trigger at startup with a delay to ensure WSL is ready
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT30S'  # 30 second delay

# Run as SYSTEM with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Register-ScheduledTask -TaskName "WSL2-PortForward" -Action $action -Trigger $trigger -Principal $principal -Description "Forward ports from Windows to dockeruser's WSL2 on startup"
```

**Verification:**
After reboot, check the log:
```powershell
Get-Content C:\Scripts\portforward.log
```

This ensures port forwarding is automatically configured with the correct IP after every reboot.

## Deployment Commands

### Start Services
```powershell
# From local machine with lab context
docker context use lab
docker compose up -d
```

### View Logs
```powershell
docker compose logs -f
# Or individually
docker logs litellm
docker logs open-webui
```

### Stop Services
```powershell
docker compose down
```

### Check Status
```powershell
docker ps
wsl -l -v
```

## Architecture

```
[Local Machine] 
    ↓ (SSH via Docker Context)
[Windows Server 2022]
    ↓ (WSL2)
[Ubuntu + Docker]
    ↓
[Docker Compose]
    ├─ LiteLLM (port 4000) → Azure AI Foundry
    └─ Open WebUI (port 3000) → LiteLLM

[IIS on Windows]
    └─ Port 8080 → Reverse Proxy → localhost:3000
```

## Security Notes
- SSH key-based authentication for secure remote access
- Generated cryptographically secure API key for LiteLLM
- Environment variables stored in `.env` (not committed to git)
- Firewall configured to allow only necessary ports
