# Azure Deployment Guide

This guide deploys the Azure reference architecture described in
[`docs/customer-reference-architecture.md`](docs/customer-reference-architecture.md).
It uses Bicep as the infrastructure source of truth and a local azd environment
as the Git-ignored store for deployment inputs.

## Prerequisites

- Azure CLI, Azure Developer CLI, and Bicep.
- An Azure subscription where the deploying operator can create resources and
  role assignments.
- A supported primary region for Container Apps, PostgreSQL Flexible Server,
  Microsoft Foundry, and Azure AI Search.
- A paired-region plan for APIM if Basic v2 capacity is unavailable in the
  primary region.

For SharePoint ingestion and Foundry IQ prerequisites, see the customer
reference architecture.

## Create an azd environment

Create one local environment per Azure deployment. Its contents live under
`.azure/<environment>/` and are excluded from Git.

```powershell
azd auth login
azd env new <environment-name> --no-prompt

azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_LOCATION <primary-region>
azd env set AZURE_ENV_NAME <environment-name>
```

Set all Bicep parameters through the azd infrastructure configuration. Secure
values remain local to the azd environment.

```powershell
azd env config set infra.parameters.apimLocation <apim-region>
azd env config set infra.parameters.litellmMasterKey <random-secret>
azd env config set infra.parameters.openWebUiSecretKey <random-secret>
azd env config set infra.parameters.postgresAdminPassword <random-secret>
azd env config set infra.parameters.apimFoundryAgentSubscriptionKey <random-secret>
azd env config set infra.parameters.apimPublisherEmail <publisher-email>

azd env config set infra.parameters.litellmContainerImage ghcr.io/berriai/litellm:v1.104.0
azd env config set infra.parameters.openwebuiContainerImage ghcr.io/open-webui/open-webui:v0.11.4
azd env config set infra.parameters.vnetAddressPrefix 10.101.0.0/16
azd env config set infra.parameters.containerAppsSubnetPrefix 10.101.0.0/23
azd env config set infra.parameters.postgresSubnetPrefix 10.101.2.0/28
azd env config set infra.parameters.searchSkuName basic
azd env config set infra.parameters.promptAgentName poppy-general-agent
azd env config set infra.parameters.promptAgentModelAlias poppy-general-agent-responses
```

For a new environment, set:

```powershell
azd env config set infra.parameters.provisionNetwork true
```

After the initial deployment creates delegated Container Apps and PostgreSQL
subnets, set it to `false`. This prevents later configuration deployments from
attempting an immutable update to an in-use delegated subnet:

```powershell
azd env config set infra.parameters.provisionNetwork false
```

## Validate and deploy

Compile the Bicep source:

```powershell
az bicep build --file infra/main.bicep
```

Preview the deployment:

```powershell
.\scripts\deploy_from_azd_environment.ps1 -Mode WhatIf
```

After reviewing the what-if, deploy:

```powershell
.\scripts\deploy_from_azd_environment.ps1 -Mode Deploy
```

The script reads values from the active azd environment and passes them to ARM
in memory. It does not write a parameter file containing secrets.

## Post-deployment configuration

1. Create or update Foundry prompt agents with the scripts in `scripts/`.
2. Configure the SharePoint indexer application, Microsoft Graph
   `Sites.Selected`, and the explicit per-site `read` grant.
3. Apply the Search knowledge source, indexer override, and knowledge base:

   ```powershell
   .\scripts\apply_search_knowledge_source.ps1 ...
   .\scripts\apply_sharepoint_indexer_citation_mapping.ps1 ...
   .\scripts\apply_search_knowledge_base.ps1 ...
   .\scripts\apply_foundry_iq_connection.ps1 ...
   ```

4. Validate the model aliases through APIM and OpenWebUI.

## Operations

OpenWebUI is public; LiteLLM is internal-only. The OpenWebUI signing key must
remain stable across revisions or existing browser sessions become invalid.

Use Container Apps logs and Application Insights/APIM diagnostics to
troubleshoot:

```powershell
az containerapp logs show --name ca-openwebui-<environment-name> --resource-group rg-<environment-name> --follow
az containerapp logs show --name ca-litellm-<environment-name> --resource-group rg-<environment-name> --follow
```

## Cleanup

Deleting a resource group removes all contained resources and data. Export
required artifacts and obtain explicit approval before cleanup.
