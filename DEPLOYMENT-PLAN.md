# Azure Container Apps Deployment Plan

## Overview
Deploy Open WebUI and LiteLLM from Docker Compose to Azure Container Apps with Infrastructure as Code (Bicep).

## Current State (Local Docker)
- **LiteLLM**: Proxy service for Azure AI models on port 4000
- **Open WebUI**: Web interface on port 3000
- **Configuration**: litellm-config.yaml with Azure AI model definitions
- **Environment**: Docker Compose with bridge network
- **Storage**: Docker volume for Open WebUI data

## Target State (Azure Container Apps)
- **LiteLLM Container App**: Internal ingress only, communicates with Azure AI Foundry
- **Open WebUI Container App**: External HTTPS ingress, consumes LiteLLM API
- **Storage**: Azure Files share for persistent data
- **Networking**: Internal Container Apps Environment networking
- **Monitoring**: Log Analytics workspace integration
- **Security**: HTTPS, managed secrets, minimal external exposure

## Implementation Plan

### Phase 1: Preparation (Manual)
**Tasks:**
1. ✅ Create `SETUP-AZURE-CONTAINER-APPS.md` with deployment guide
2. Create `.env.azure.template` for Azure environment variables
3. Gather required Azure information:
   - Azure subscription ID
   - Resource group name (new or existing)
   - Azure region (e.g., eastus, westus2)
   - Azure AI Foundry credentials (same as local)
   - Generate LiteLLM master key (random secure string)

**Validation:**
- Azure CLI installed and authenticated (`az login`)
- Sufficient subscription quota for Container Apps
- Region supports Container Apps

### Phase 2: Infrastructure as Code (Bicep)
**Tasks:**
1. Create `infra/` directory structure:
   ```
   infra/
   ├── main.bicep                    # Main orchestration
   ├── main.parameters.json          # Parameter values
   ├── modules/
   │   ├── container-apps-env.bicep  # Container Apps Environment
   │   ├── litellm-app.bicep         # LiteLLM Container App
   │   ├── openwebui-app.bicep       # Open WebUI Container App
   │   └── storage.bicep             # Azure Files for persistence
   ```

2. **main.bicep** - Orchestrate all resources:
   - Parameters: location, names, Azure AI credentials
   - Output: Application URLs, resource IDs

3. **container-apps-env.bicep** - Create environment:
   - Log Analytics workspace
   - Container Apps Environment
   - Internal networking configuration

4. **storage.bicep** - Persistent storage:
   - Storage account (Standard LRS)
   - File share for Open WebUI data
   - SMB protocol configuration

5. **litellm-app.bicep** - LiteLLM service:
   - Container: `ghcr.io/berriai/litellm:main-latest`
   - Ingress: Internal only, port 4000
   - Secrets: Azure API credentials, master key
   - Config: Mount litellm-config.yaml as secret
   - Resources: 0.5 vCPU, 1.0 GB RAM
   - Scaling: 1-3 replicas

6. **openwebui-app.bicep** - Open WebUI service:
   - Container: `ghcr.io/open-webui/open-webui:main`
   - Ingress: External HTTPS, port 8080
   - Environment: Point to internal LiteLLM URL
   - Storage: Mount Azure Files to `/app/backend/data`
   - Resources: 1.0 vCPU, 2.0 GB RAM
   - Scaling: 1-5 replicas
   - Dependencies: Requires LiteLLM to be running

7. **main.parameters.json** - Configuration values:
   - Default resource names
   - Default region
   - Default resource allocations
   - Overridable at deployment time

**Validation:**
- Bicep files lint without errors (`az bicep build`)
- What-if deployment shows expected resources
- Follow Azure best practices (latest API versions, no hardcoded secrets)

### Phase 3: Deployment Automation
**Tasks:**
1. Create `deploy-azure.ps1` PowerShell script:
   - Load `.env.azure` file
   - Validate prerequisites (Azure CLI, logged in, subscription)
   - Check resource quota and region availability
   - Create resource group if needed
   - Run `az deployment group what-if` for preview
   - Prompt user confirmation
   - Execute `az deployment group create`
   - Retrieve and display deployment outputs (URLs)
   - Test Open WebUI URL for responsiveness
   - Display Azure Portal link to resource group

2. Error handling:
   - Check for missing environment variables
   - Validate Azure CLI version
   - Handle deployment failures gracefully
   - Provide clear error messages

**Validation:**
- Script runs successfully from start to finish
- All resources created correctly
- URLs are accessible
- Logs show containers starting successfully

### Phase 4: Verification & Testing
**Tasks:**
1. Deploy to Azure using the script
2. Verify container health:
   ```powershell
   az containerapp show --name litellm-app --resource-group [RG] --query properties.runningStatus
   az containerapp show --name openwebui-app --resource-group [RG] --query properties.runningStatus
   ```
3. Check application logs for errors
4. Access Open WebUI via HTTPS URL
5. Test authentication and model access
6. Verify data persistence (create data, restart container, verify data exists)
7. Test scaling behavior (manual scale up/down)

**Validation:**
- Open WebUI loads successfully
- Can authenticate and use the application
- Models from Azure AI Foundry are accessible
- Data persists across container restarts
- No errors in application logs

### Phase 5: Documentation & Cleanup
**Tasks:**
1. Update `README.md` to reference Azure deployment option
2. Document cost estimates and optimization tips
3. Document troubleshooting common issues
4. Create cleanup instructions

**Validation:**
- Documentation is clear and complete
- All files are committed to repository
- Cleanup script successfully removes all resources

## Files to Create

### 1. `.env.azure.template`
Template for Azure-specific environment variables

### 2. `infra/main.bicep`
Main Bicep orchestration file (IaC)

### 3. `infra/main.parameters.json`
Default parameters for Bicep deployment

### 4. `infra/modules/container-apps-env.bicep`
Container Apps Environment and Log Analytics

### 5. `infra/modules/storage.bicep`
Azure Storage Account and File Share

### 6. `infra/modules/litellm-app.bicep`
LiteLLM Container App definition

### 7. `infra/modules/openwebui-app.bicep`
Open WebUI Container App definition

### 8. `deploy-azure.ps1`
PowerShell deployment automation script

## Key Considerations

### Security
- ✅ LiteLLM not exposed to internet (internal ingress only)
- ✅ HTTPS enabled on Open WebUI (Azure-managed certificates)
- ✅ Secrets stored in Container Apps environment secrets
- ✅ Azure AI credentials passed as secure parameters
- ✅ No credentials in repository

### Networking
- ✅ LiteLLM accessible via internal DNS: `http://litellm-app`
- ✅ Open WebUI configured to use internal LiteLLM URL
- ✅ Both apps in same Container Apps Environment for internal networking
- ✅ External access only through Open WebUI HTTPS endpoint

### Storage
- ✅ Azure Files used for Open WebUI data persistence
- ✅ SMB protocol for file share mounting
- ✅ Standard LRS for cost optimization
- ✅ Mount at `/app/backend/data` matching Docker setup

### Configuration
- ✅ litellm-config.yaml content stored as Container Apps secret
- ✅ Environment variables for Azure AI credentials
- ✅ Same model configuration as local Docker setup
- ✅ Can update config by redeploying Bicep template

### Cost Optimization
- Start with minimal replicas (1 min, 3-5 max)
- Use consumption-based pricing (pay per vCPU-second)
- Standard LRS storage (cheapest tier)
- Can scale to zero for non-production environments

### Monitoring
- Log Analytics workspace for centralized logs
- Container Apps built-in metrics
- Can add Application Insights for advanced monitoring

## Estimated Costs (USD/month)
- **Container Apps Environment**: Free (first 180,000 vCPU-seconds/month)
- **LiteLLM App**: ~$10-15 (low usage, 0.5 vCPU, 1 GB RAM)
- **Open WebUI App**: ~$15-25 (moderate usage, 1 vCPU, 2 GB RAM)
- **Storage**: ~$2-5 (Standard LRS, small file share)
- **Log Analytics**: ~$2-5 (500 MB daily ingestion)
- **Total Estimated**: $29-50/month (varies with usage)

## Success Criteria
- [x] Documentation created (SETUP-AZURE-CONTAINER-APPS.md)
- [ ] All infrastructure files created and tested
- [ ] Deployment script created and functional
- [ ] Successfully deployed to Azure
- [ ] Open WebUI accessible via HTTPS
- [ ] LiteLLM successfully proxying Azure AI models
- [ ] Data persistence verified
- [ ] Logs accessible and showing healthy state
- [ ] Cost within expected range

## Rollback Plan
If deployment fails or issues arise:
1. Review deployment logs: `az deployment group show`
2. Review container logs: `az containerapp logs show`
3. Delete resource group: `az group delete --name [RG] --yes`
4. Return to local Docker setup
5. Fix issues and retry deployment

## Next Steps After Review
Once the plan is approved:
1. Create `.env.azure.template` file
2. Create Bicep infrastructure files in `infra/` directory
3. Create `deploy-azure.ps1` deployment script
4. Test deployment to Azure subscription
5. Verify functionality
6. Update documentation with any lessons learned
