# Open WebUI + LiteLLM with Azure AI Foundry

Deploy Open WebUI with LiteLLM as a proxy to your Azure AI Foundry models. This repository is configured for **Azure Container Apps** deployment using Azure Developer CLI (azd), with Docker Compose available for local development.

## 🚀 Quick Start - Deploy to Azure

Deploy to Azure Container Apps with a single command:

```bash
# Install Azure Developer CLI if you haven't already
# Windows: winget install microsoft.azd
# macOS: brew tap azure/azd && brew install azd
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash

# Initialize and deploy
azd auth login
azd up
```

The `azd up` command will:
1. Prompt you for Azure subscription, location, and environment name
2. Ask for your Azure AI Foundry credentials
3. Provision all Azure resources (Container Apps, Storage, Log Analytics)
4. Deploy the containers
5. Provide you with the HTTPS URL to access Open WebUI

**First-time setup takes ~5-10 minutes.** Updates with `azd deploy` take ~2-3 minutes.

### Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Azure subscription with permissions to create resources
- Azure AI Foundry with deployed models (gpt-4o, gpt-4o-mini, etc.)

### Configuration

Before running `azd up`, you'll be prompted for:

```bash
# Required
AZURE_API_BASE=https://your-project.openai.azure.com/
LITELLM_MASTER_KEY=sk-your-secure-random-key

# Authentication - Choose one:
# Option 1: API Key (simpler for testing)
USE_MANAGED_IDENTITY=false
AZURE_API_KEY=your-azure-api-key

# Option 2: Managed Identity (recommended for production - no key needed!)
# USE_MANAGED_IDENTITY=true
# AZURE_API_KEY=  # Leave empty
```

**Managed Identity** provides passwordless authentication and is more secure for production. See [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md) for configuration details.

**📖 Detailed Azure deployment instructions:** [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)

---

## 💻 Local Development with Docker Compose

For local development and testing, you can run the stack with Docker Compose:

### 1. Configure Environment

Copy `.env.template` to `.env` and fill in your Azure AI Foundry credentials:

```bash
cp .env.template .env
```

Edit `.env` with your values:
- `AZURE_API_KEY`: Your Azure API key
- `AZURE_API_BASE`: Your Azure endpoint
- `AZURE_API_VERSION`: API version (typically `2024-08-01-preview`)
- `LITELLM_MASTER_KEY`: A secure random key

### 2. Start Services

```bash
docker-compose up -d
```

### 3. Access Open WebUI

Open your browser to http://localhost:3000

**📖 Complete local setup guide:** [SETUP-LOCAL.md](SETUP-LOCAL.md)

---

## 📝 Model Configuration

Edit `litellm-config.yaml` to add your Azure AI Foundry deployed models:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: ${AZURE_API_BASE}
      api_key: ${AZURE_API_KEY}
      api_version: ${AZURE_API_VERSION}
```

**For Azure deployments:** After updating `litellm-config.yaml`, redeploy with:
```bash
azd deploy
```

**For local Docker:** Restart the LiteLLM container:
```bash
docker-compose restart litellm
```

---

## 🏗️ Architecture

### Azure Container Apps Deployment
- **Open WebUI**: External HTTPS ingress, auto-scaling (1-5 replicas)
- **LiteLLM**: Internal-only ingress, auto-scaling (1-3 replicas)
- **Storage**: Azure Files for persistent data
- **Monitoring**: Log Analytics workspace integration

### Local Docker Deployment
- **Open WebUI**: http://localhost:3000
- **LiteLLM**: http://localhost:4000 (internal)
- **Storage**: Docker volume
- **Network**: Bridge network for inter-container communication

---

## 📚 Documentation

- **[SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)** - Complete Azure deployment guide
- **[SETUP-LOCAL.md](SETUP-LOCAL.md)** - Local Docker Compose development guide
- **[DEPLOYMENT-PLAN.md](DEPLOYMENT-PLAN.md)** - Technical implementation details

---

## 🛠️ Management Commands

### Azure Container Apps

```bash
# View logs
azd monitor --logs

# Redeploy containers
azd deploy

# View resource in Azure Portal
azd show

# Tear down all resources
azd down
```

### Local Docker Compose

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Update images
docker-compose pull && docker-compose up -d
```

---

## 💰 Cost Estimate (Azure)

Running in Azure Container Apps (consumption plan):
- **Container Apps**: ~$20-40/month (varies with usage)
- **Storage**: ~$2-5/month (10GB Azure Files)
- **Log Analytics**: ~$2-5/month (500MB/day)
- **Total**: ~$24-50/month for low-moderate usage

*Actual costs depend on usage patterns, region, and scaling configuration.*

---

## 🔒 Security Features (Azure)

- ✅ HTTPS enabled by default (Azure-managed certificates)
- ✅ LiteLLM not exposed to internet (internal ingress only)
- ✅ Secrets stored securely in Container Apps environment
- ✅ Azure Files access via managed keys
- ✅ Log Analytics for audit trails

---

## 🆘 Troubleshooting

### Azure Deployment Issues
```bash
# View deployment logs
azd monitor --logs --service openwebui
azd monitor --logs --service litellm

# Check resource status
azd show
```

### Local Docker Issues
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs litellm
docker-compose logs open-webui

# Test LiteLLM health
curl http://localhost:4000/health
```

---

## 🤝 Contributing

This repository follows Azure Developer CLI (azd) conventions:
- `azure.yaml` - azd configuration
- `infra/` - Bicep infrastructure as code
- `docker-compose.yml` - Local development setup

---

## 📄 License

See individual component licenses:
- [Open WebUI](https://github.com/open-webui/open-webui)
- [LiteLLM](https://github.com/BerriAI/litellm)

---

## 🔗 Related Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
