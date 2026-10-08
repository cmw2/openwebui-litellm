# Open WebUI + LiteLLM with Azure AI Foundry

Deploy Open WebUI with LiteLLM as a proxy to your Azure AI Foundry models. This repository is configured for **Azure Container Apps** deployment using Azure Developer CLI (azd).

## Sample Code

This repository contains sample code intended for demonstration purposes. It
shows one way to integrate OpenWebUI, LiteLLM, API Management, Microsoft
Foundry, Azure AI Search, and SharePoint content. The code is provided as-is
and will require review, validation, and likely modification before use in a
production environment.

## Disclaimer

**This Sample Code is provided for the purpose of illustration only and is not
intended to be used in a production environment. THIS SAMPLE CODE AND ANY
RELATED INFORMATION ARE PROVIDED 'AS IS' WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.**

## 🚀 Quick Start - Deploy to Azure

Deploy to Azure Container Apps with a single command:

```bash
# Install Azure Developer CLI if you haven't already
# Windows: winget install microsoft.azd
# macOS: brew tap azure/azd && brew install azd
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash

# Authenticate and create a local, Git-ignored azd environment
azd auth login
azd env new <environment-name> --no-prompt
```

Configure the environment and deploy using the
[Azure deployment guide](SETUP-AZURE-CONTAINER-APPS.md). It documents the
required secure parameters, initial-network lifecycle setting, what-if, and
deployment helper.

**Allow 30-60 minutes for the first infrastructure deployment.** API Management,
private PostgreSQL, Container Apps, Foundry model deployments, and Azure AI
Search each provision independently. SharePoint ingestion, knowledge-base
assets, and prompt-agent configuration are follow-on steps described in the
[customer reference architecture](docs/customer-reference-architecture.md).

After the foundation exists, an application/container configuration update is
typically much faster, but still depends on Container Apps revision startup and
APIM propagation.

### Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Azure subscription with permissions to create resources

### Configuration

Before running `azd up`, you'll be prompted for:

The required secure values are `litellmMasterKey`, `openWebUiSecretKey`,
`postgresAdminPassword`, and `apimFoundryAgentSubscriptionKey`. Store them in
the Git-ignored azd environment using `azd env config set
infra.parameters.<name> <value>`; do not place them in source files.

LiteLLM uses its managed identity only for its direct Azure OpenAI/Foundry
deployment aliases: `gpt-5.4` and `gpt-5.4-mini`. Those aliases are
advertised in OpenWebUI alongside the Foundry agent aliases. The
Foundry **agent** aliases use a different, deliberate path: LiteLLM calls APIM
with a product-scoped
subscription key, and APIM uses its managed identity to access the Foundry
agent endpoint. No Foundry resource key is required.

### Declarative APIM-backed Foundry agents

During deployment, Bicep loads the checked-in
[`infra/app/litellm-config.yaml`](infra/app/litellm-config.yaml) template,
substitutes nonsecret model-alias values, and stores the resulting configuration
as a Container Apps secret. At startup, the LiteLLM container writes that
secret to its own ephemeral `/app/config.yaml`; no rendered configuration file
is created in the repository or workspace. Model aliases are not created
through LiteLLM's administrative API.
For the APIM-backed Foundry prompt-agent alias, provision a cryptographically
random subscription key once:

```powershell
azd env set apimFoundryAgentSubscriptionKey '<random-value>'
```

The deployment assigns that value as the LiteLLM-only APIM product
subscription primary key and injects it into LiteLLM as a Container Apps
secret. The checked-in YAML contains only an environment-variable reference;
the actual key is supplied only as the `Ocp-Apim-Subscription-Key` request
header. It is never committed to source control or stored in LiteLLM's model
database.

`store_model_in_db` is deliberately disabled so the checked-in `model_list`
remains the source of truth. PostgreSQL remains available for LiteLLM
operational state, but changing an agent route or alias requires an IaC
deployment rather than an administrative API call.

**📖 Detailed Azure deployment instructions:** [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)

**📖 Customer reference architecture:** [docs/customer-reference-architecture.md](docs/customer-reference-architecture.md)

**📖 SharePoint Indexed knowledge source guide:** [docs/sharepoint-indexed-knowledge-source-guide.md](docs/sharepoint-indexed-knowledge-source-guide.md)

## 📝 Model Configuration

The Azure deployment provisions `gpt-5.4` and `gpt-5.4-mini` and exposes them
through LiteLLM:

```yaml
model_list:
  - model_name: gpt-5.4
    litellm_params:
      model: azure/gpt-5.4
      api_base: os.environ/AZURE_API_BASE
      api_version: os.environ/AZURE_API_VERSION
```

**For Azure deployments:** After updating `infra/app/litellm-config.yaml`,
preview and deploy with:
```bash
.\scripts\deploy_from_azd_environment.ps1 -Mode WhatIf
.\scripts\deploy_from_azd_environment.ps1 -Mode Deploy
```

## 🏗️ Architecture

### Azure Container Apps Deployment
- **Open WebUI**: External HTTPS ingress with a stable signing key and scale to zero
- **LiteLLM**: Internal-only ingress, declarative aliases, and scale to zero
- **API Management**: OpenAI Responses compatibility façade, managed identity to Foundry, API-scoped LiteLLM product subscription, and diagnostics
- **Microsoft Foundry**: Account, project, GPT model deployments, and prompt agents
- **Azure AI Search**: Semantic/hybrid retrieval, indexed SharePoint knowledge source, and Foundry IQ knowledge base
- **Storage**: Private PostgreSQL Flexible Server for OpenWebUI and LiteLLM operational state
- **Network**: VNet-integrated Container Apps; PostgreSQL has no public access
- **Monitoring**: Log Analytics, Application Insights, APIM diagnostics, and a Foundry Application Insights connection

## 📚 Documentation

- **[SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)** - Complete Azure deployment guide
- **[docs/customer-reference-architecture.md](docs/customer-reference-architecture.md)** - Customer architecture, permissions, and preview guidance
- **[docs/sharepoint-indexed-knowledge-source-guide.md](docs/sharepoint-indexed-knowledge-source-guide.md)** - Portal-first and automation-first SharePoint ingestion guide

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

## 💰 Cost Considerations

Container Apps can scale to zero, but API Management Basic v2, Azure AI Search,
private PostgreSQL, and observability can have nonzero baseline cost. Review
regional pricing and required SKU availability before deployment. The customer
reference architecture explains the tradeoffs.

---

## 🔒 Security Features (Azure)

- ✅ HTTPS enabled by default (Azure-managed certificates)
- ✅ LiteLLM not exposed to internet (internal ingress only)
- ✅ Secrets stored securely in Container Apps environment
- ✅ Managed identities for Foundry and Search access where supported
- ✅ Private PostgreSQL networking
- ✅ Log Analytics, Application Insights, and APIM diagnostics

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

## 🤝 Contributing

This repository follows Azure Developer CLI (azd) conventions:
- `azure.yaml` - azd configuration
- `infra/` - Bicep infrastructure as code

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
