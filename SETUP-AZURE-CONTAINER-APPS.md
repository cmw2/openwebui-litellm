# Deploy Open WebUI + LiteLLM to Azure Container Apps

This guide will help you deploy Open WebUI and LiteLLM to Azure Container Apps using Infrastructure as Code (Bicep).

## Architecture Overview

The deployment creates:
- **Azure Container Apps Environment**: Managed Kubernetes environment for hosting containers
- **LiteLLM Container App**: Proxy service for Azure AI models (internal ingress)
- **Open WebUI Container App**: Web interface (external ingress with HTTPS)
- **Azure Files Share**: Persistent storage for Open WebUI data
- **Log Analytics Workspace**: Centralized logging and monitoring

## Prerequisites

1. **Azure CLI** installed and configured
   ```powershell
   az --version
   az login
   ```

2. **Azure Subscription** with permissions to create resources

3. **Azure AI Foundry** models already deployed (same as local setup)

4. **Resource Requirements**:
   - Resource Group (or create new)
   - Unique names for Container Apps
   - Region with Container Apps availability (e.g., eastus, westus2, westeurope)

## Deployment Steps

### 1. Configure Environment Variables

Copy the Azure environment template:
```powershell
cp .env.azure.template .env.azure
```

Edit `.env.azure` with your values:
```bash
# Azure Subscription & Resource Group
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_RESOURCE_GROUP=openwebui-rg
AZURE_LOCATION=eastus

# Authentication Method - Choose one:
# Option A: Use API Key (traditional)
USE_MANAGED_IDENTITY=false
AZURE_API_KEY=your-azure-api-key

# Option B: Use Managed Identity (recommended for production)
# USE_MANAGED_IDENTITY=true
# AZURE_API_KEY=  # Leave empty when using managed identity

# Azure AI Foundry Configuration
AZURE_API_BASE=https://your-project.openai.azure.com/
AZURE_API_VERSION=2024-08-01-preview

# LiteLLM Master Key (generate a secure random string)
LITELLM_MASTER_KEY=sk-1234567890abcdef

# Container Apps Configuration
CONTAINER_APPS_ENVIRONMENT_NAME=openwebui-env
LITELLM_APP_NAME=litellm-app
OPENWEBUI_APP_NAME=openwebui-app
```

**Authentication Options:**

- **API Key Mode** (`USE_MANAGED_IDENTITY=false`): Traditional authentication using Azure API keys. Simpler for testing but requires key management.
  
- **Managed Identity Mode** (`USE_MANAGED_IDENTITY=true`): Uses Azure Managed Identity for authentication. More secure, no keys to manage, follows Azure best practices. **Recommended for production deployments.**

### 2. Validate Azure Quota and Region Availability

Before deploying, check if your subscription has sufficient quota:
```powershell
az containerapp env list --subscription $env:AZURE_SUBSCRIPTION_ID
az provider show --namespace Microsoft.App --query "resourceTypes[?resourceType=='containerApps'].locations"
```

### 3. Deploy Infrastructure with Bicep

The deployment uses Bicep templates in the `infra/` directory:

```powershell
# Set your subscription
az account set --subscription $env:AZURE_SUBSCRIPTION_ID

# Create resource group (if it doesn't exist)
az group create `
  --name $env:AZURE_RESOURCE_GROUP `
  --location $env:AZURE_LOCATION

# Preview the deployment (What-If)
az deployment group what-if `
  --name openwebui-deployment `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --template-file infra/main.bicep `
  --parameters infra/main.parameters.json `
  --parameters azureApiKey=$env:AZURE_API_KEY `
  --parameters azureApiBase=$env:AZURE_API_BASE `
  --parameters azureApiVersion=$env:AZURE_API_VERSION `
  --parameters litellmMasterKey=$env:LITELLM_MASTER_KEY

# Deploy (after reviewing what-if results)
az deployment group create `
  --name openwebui-deployment `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --template-file infra/main.bicep `
  --parameters infra/main.parameters.json `
  --parameters azureApiKey=$env:AZURE_API_KEY `
  --parameters azureApiBase=$env:AZURE_API_BASE `
  --parameters azureApiVersion=$env:AZURE_API_VERSION `
  --parameters litellmMasterKey=$env:LITELLM_MASTER_KEY
```

### 4. Alternative: Use Deployment Script

For convenience, use the provided PowerShell script:
```powershell
.\deploy-azure.ps1
```

This script will:
1. Load environment variables from `.env.azure`
2. Validate prerequisites
3. Run what-if analysis
4. Deploy infrastructure
5. Configure container apps
6. Display deployment URLs

### 5. Access Your Deployment

After deployment completes, you'll receive:
- **Open WebUI URL**: `https://[your-app-name].azurecontainerapps.io`
- **Resource Group**: Link to Azure Portal

The first startup may take 2-3 minutes as containers initialize.

## Configuration Details

### LiteLLM Container App
- **Image**: `ghcr.io/berriai/litellm:main-latest`
- **Port**: 4000
- **Ingress**: Internal only (not exposed to internet)
- **CPU/Memory**: 0.5 vCPU, 1.0 GB RAM
- **Scaling**: 1-3 replicas

### Open WebUI Container App
- **Image**: `ghcr.io/open-webui/open-webui:main`
- **Port**: 8080
- **Ingress**: External with HTTPS
- **CPU/Memory**: 1.0 vCPU, 2.0 GB RAM
- **Scaling**: 1-5 replicas
- **Storage**: Azure Files mounted at `/app/backend/data`

### Security Features
- HTTPS enabled by default on external ingress
- Internal communication between containers (LiteLLM not exposed)
- Secrets stored in Container Apps environment
- **Managed Identity support**: Optional passwordless authentication to Azure AI services

### Using Managed Identity (Post-Deployment Configuration)

If you deployed with `USE_MANAGED_IDENTITY=true`, you need to grant the LiteLLM container app's managed identity access to your Azure AI Foundry resource:

1. **Get the Managed Identity Principal ID**:
   ```powershell
   $principalId = az containerapp show `
     --name ca-litellm-${AZURE_ENV_NAME} `
     --resource-group rg-${AZURE_ENV_NAME} `
     --query identity.principalId -o tsv
   ```

2. **Grant "Cognitive Services OpenAI User" role** to the managed identity on your Azure AI Foundry resource:
   ```powershell
   # Get your Azure AI Foundry resource ID
   $aiResourceId = az cognitiveservices account show `
     --name your-ai-foundry-name `
     --resource-group your-ai-foundry-rg `
     --query id -o tsv

   # Assign role
   az role assignment create `
     --role "Cognitive Services OpenAI User" `
     --assignee-object-id $principalId `
     --scope $aiResourceId
   ```

3. **Verify the container app restarts** (may happen automatically):
   ```powershell
   az containerapp revision list `
     --name ca-litellm-${AZURE_ENV_NAME} `
     --resource-group rg-${AZURE_ENV_NAME}
   ```

**Note**: When using managed identity, no API key is stored in secrets - authentication happens transparently using Azure AD tokens that are automatically refreshed.

## Managing Your Deployment

### View Logs
```powershell
# LiteLLM logs
az containerapp logs show `
  --name $env:LITELLM_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --follow

# Open WebUI logs
az containerapp logs show `
  --name $env:OPENWEBUI_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --follow
```

### Update Container Images
```powershell
# Update LiteLLM
az containerapp update `
  --name $env:LITELLM_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --image ghcr.io/berriai/litellm:main-latest

# Update Open WebUI
az containerapp update `
  --name $env:OPENWEBUI_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --image ghcr.io/open-webui/open-webui:main
```

### Scale Applications
```powershell
# Scale Open WebUI
az containerapp update `
  --name $env:OPENWEBUI_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --min-replicas 2 `
  --max-replicas 10
```

### Update Model Configuration

To add or modify models:
1. Update `litellm-config.yaml` with new model definitions
2. Redeploy the Bicep template (it will update the secret)
3. Restart LiteLLM container app:
   ```powershell
   az containerapp revision restart `
     --name $env:LITELLM_APP_NAME `
     --resource-group $env:AZURE_RESOURCE_GROUP
   ```

## Cost Optimization

- **Scaling**: Configure min replicas to 0 for non-production to scale to zero
- **Resources**: Adjust CPU/memory based on actual usage
- **Consumption Plan**: Pay only for actual usage (vCPU-seconds and memory GB-seconds)
- **Estimated Cost**: ~$20-50/month for low-moderate usage

## Troubleshooting

### Container won't start
```powershell
# Check revision provisioning state
az containerapp revision list `
  --name $env:OPENWEBUI_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --output table

# View detailed logs
az containerapp logs show `
  --name $env:OPENWEBUI_APP_NAME `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --tail 100
```

### LiteLLM connection issues
- Verify internal ingress is enabled on LiteLLM
- Check environment variable: `OPENAI_API_BASE_URL` should be `http://litellm-app/v1`
- Verify both apps are in the same Container Apps Environment

### Storage issues
- Ensure Azure Files share is properly mounted
- Check storage account connectivity
- Verify SMB configuration

## Cleanup

To remove all resources:
```powershell
az group delete --name $env:AZURE_RESOURCE_GROUP --yes --no-wait
```

## Next Steps

- **Custom Domain**: Add your own domain with managed certificates
- **Authentication**: Enable Azure AD authentication for Open WebUI
- **Monitoring**: Set up alerts in Log Analytics
- **Backup**: Configure automated backups of Azure Files share
- **CI/CD**: Set up GitHub Actions for automated deployments

## Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
