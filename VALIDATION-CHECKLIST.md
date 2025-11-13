# Pre-Deployment Validation Checklist

Complete this checklist before deploying to ensure everything is configured correctly.

## ✅ Repository Structure

- [x] `azure.yaml` exists and is properly configured
- [x] `infra/main.bicep` exists
- [x] `infra/main.parameters.json` exists
- [x] `infra/core/` directory contains monitoring, storage, and container-apps-env modules
- [x] `infra/app/` directory contains litellm and openwebui modules
- [x] All Bicep files compile without errors (`az bicep build`)
- [x] Documentation is complete (README, setup guides)

## 🔧 Prerequisites

- [ ] Azure CLI installed (`az --version`)
- [ ] Azure Developer CLI installed (`azd version`)
- [ ] Logged into Azure (`az login` and `azd auth login`)
- [ ] Azure subscription identified
- [ ] Azure AI Foundry endpoint and API key available
- [ ] Region selected (supports Container Apps)

## 📝 Configuration Files

### For Local Development
- [ ] `.env` file created from `.env.template`
- [ ] `AZURE_API_KEY` set in `.env`
- [ ] `AZURE_API_BASE` set in `.env`
- [ ] `AZURE_API_VERSION` set in `.env` (or default 2024-08-01-preview)
- [ ] `LITELLM_MASTER_KEY` set in `.env` (secure random string)
- [ ] `litellm-config.yaml` updated with your model deployments

### For Azure Deployment
- [ ] Environment variables ready (azd will prompt, or set in `.azure/<env>/.env`)
- [ ] `AZURE_API_KEY` ready
- [ ] `AZURE_API_BASE` ready
- [ ] `AZURE_API_VERSION` ready (or use default)
- [ ] `LITELLM_MASTER_KEY` generated (secure random string, e.g., `sk-` + 32 random chars)

## 🧪 Local Testing (Recommended First)

- [ ] Docker and Docker Compose installed
- [ ] Start local stack: `docker-compose up -d`
- [ ] Check containers are running: `docker-compose ps`
- [ ] LiteLLM health check: `curl http://localhost:4000/health`
- [ ] Access Open WebUI: http://localhost:3000
- [ ] Create test account in Open WebUI
- [ ] Verify models appear in dropdown
- [ ] Test a simple chat with a model
- [ ] Stop local stack: `docker-compose down`

## 🚀 Azure Deployment Validation

### Pre-Deployment
- [ ] Bicep files validated: `az bicep build --file infra/main.bicep`
- [ ] Review resource names and tags in `infra/main.bicep`
- [ ] Confirm estimated costs (~$25-50/month for this configuration)
- [ ] Choose environment name (3-24 chars, lowercase, no special chars except `-`)

### Deployment Steps
- [ ] Run `azd auth login`
- [ ] Run `azd up` (or `azd init` if first time)
- [ ] When prompted, provide:
  - [ ] Azure subscription
  - [ ] Azure location (e.g., eastus, westus2, westeurope)
  - [ ] Environment name (e.g., dev, test, prod)
  - [ ] Azure AI Foundry credentials
  - [ ] LiteLLM master key
- [ ] Wait for deployment to complete (5-10 minutes)
- [ ] Note the Open WebUI URL from output

### Post-Deployment Validation
- [ ] Access Open WebUI at the provided HTTPS URL
- [ ] Verify HTTPS certificate is valid (no browser warnings)
- [ ] Create admin account
- [ ] Verify models appear in model dropdown
- [ ] Test chat with a model
- [ ] Check logs: `azd monitor --logs`
- [ ] Verify no errors in logs
- [ ] Check Azure Portal:
  - [ ] Resource group created
  - [ ] Container Apps Environment exists
  - [ ] Both Container Apps are running
  - [ ] Storage account and file share exist
  - [ ] Log Analytics workspace exists
- [ ] Test data persistence:
  - [ ] Create some chat history
  - [ ] Restart Open WebUI: `az containerapp revision restart --name ca-openwebui-<env> --resource-group rg-<env>`
  - [ ] Verify chat history persists

## 🔒 Security Validation

- [ ] Open WebUI has HTTPS enabled
- [ ] LiteLLM is NOT accessible from internet (internal only)
- [ ] Secrets not visible in portal or logs
- [ ] Storage account key not exposed
- [ ] Container Apps using managed identities where possible

## 📊 Monitoring Setup

- [ ] Log Analytics workspace created
- [ ] Logs flowing from both containers
- [ ] Can query logs: `azd monitor --logs --service openwebui`
- [ ] Can query logs: `azd monitor --logs --service litellm`
- [ ] Consider setting up:
  - [ ] Log alerts for errors
  - [ ] Cost alerts
  - [ ] Performance monitoring

## 💰 Cost Management

- [ ] Reviewed estimated costs
- [ ] Set up Azure cost alerts (optional but recommended)
- [ ] Confirmed resource scaling limits are appropriate
- [ ] For non-production: Consider setting `minReplicas: 0` to save costs

## 📚 Documentation Review

- [ ] Team knows how to access Open WebUI URL
- [ ] Team knows how to view logs (`azd monitor --logs`)
- [ ] Team knows how to redeploy (`azd deploy`)
- [ ] Team knows how to add models (update `litellm-config.yaml` and redeploy)
- [ ] Team knows troubleshooting steps
- [ ] Documented in team wiki/documentation (if applicable)

## 🎯 Success Criteria

All of the following should be true:

- [ ] Open WebUI is accessible via HTTPS
- [ ] Can log in and use the application
- [ ] Azure AI Foundry models are available and working
- [ ] Chat responses are received successfully
- [ ] Data persists across container restarts
- [ ] Logs are accessible and show healthy state
- [ ] No unexpected errors in logs or portal
- [ ] Costs are within expected range

## 🧹 Cleanup (When Done Testing)

If you deployed for testing and want to remove everything:

```bash
azd down --purge --force
```

This will:
- Delete all Azure resources
- Remove the resource group
- Clean up the azd environment

**⚠️ Warning:** This is permanent and cannot be undone!

## 📞 Support Resources

If you encounter issues:

1. **Check logs:** `azd monitor --logs`
2. **Review troubleshooting:** [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md#troubleshooting)
3. **Azure Portal:** Check resource states and events
4. **Local testing:** Fall back to Docker Compose to isolate issues
5. **Bicep validation:** Re-run `az bicep build --file infra/main.bicep`

## ✅ Checklist Complete

Once all items are checked:
- ✅ **Local development is working**
- ✅ **Azure deployment is successful**
- ✅ **Application is functional**
- ✅ **Team is trained**
- ✅ **Monitoring is in place**

**You're ready for production!** 🎉

---

**Deployment Date:** ___________  
**Deployed By:** ___________  
**Environment:** ___________  
**Azure Subscription:** ___________  
**Resource Group:** ___________  
**Open WebUI URL:** ___________
