# Managed Identity Support

This deployment now supports **two authentication modes** for accessing Azure AI Foundry / Azure OpenAI services:

## Authentication Options

### Option 1: API Key (Traditional)
- Uses Azure API keys stored as secrets
- Simpler setup, good for testing and development
- Requires key rotation and management

### Option 2: Managed Identity (Recommended for Production)
- Uses Azure Managed Identity for passwordless authentication
- More secure - no keys to manage or rotate
- Follows Azure security best practices
- Tokens are automatically refreshed by Azure

## How It Works

The implementation uses LiteLLM's `enable_azure_ad_token_refresh` feature with conditional configuration:

1. **When `USE_MANAGED_IDENTITY=false` (API Key mode)**:
   - `AZURE_API_KEY` environment variable is set from secret
   - LiteLLM uses the API key for authentication
   
2. **When `USE_MANAGED_IDENTITY=true` (Managed Identity mode)**:
   - `AZURE_API_KEY` environment variable is NOT set (empty)
   - LiteLLM automatically falls back to `DefaultAzureCredential`
   - Azure provides temporary tokens via the container's managed identity
   - System-assigned managed identity is automatically created for the LiteLLM container

## Deployment Configuration

### Using azd (Azure Developer CLI)

Set the environment variable before deploying:

```bash
# For API Key mode (default)
azd env set USE_MANAGED_IDENTITY false
azd env set AZURE_API_KEY "your-api-key"

# For Managed Identity mode (recommended)
azd env set USE_MANAGED_IDENTITY true
azd env set AZURE_API_KEY ""  # Empty or omit
```

Then deploy:
```bash
azd up
```

### Manual Deployment

When deploying manually with `az deployment group create`, pass the parameter:

```powershell
# API Key mode
az deployment group create `
  --template-file infra/main.bicep `
  --parameters useManagedIdentity=false `
  --parameters azureApiKey="your-key" `
  ...

# Managed Identity mode
az deployment group create `
  --template-file infra/main.bicep `
  --parameters useManagedIdentity=true `
  --parameters azureApiKey="" `
  ...
```

## Post-Deployment: Grant Managed Identity Access

After deploying with managed identity enabled, you must grant the container app's identity access to your Azure AI resource:

### Step 1: Get the Managed Identity Principal ID

```powershell
$principalId = az containerapp show `
  --name ca-litellm-<env-name> `
  --resource-group rg-<env-name> `
  --query identity.principalId -o tsv

echo "Managed Identity Principal ID: $principalId"
```

### Step 2: Grant Access to Azure AI Foundry

```powershell
# Get your Azure AI resource ID
$aiResourceId = az cognitiveservices account show `
  --name <your-ai-foundry-name> `
  --resource-group <your-ai-foundry-rg> `
  --query id -o tsv

# Assign "Cognitive Services OpenAI User" role
az role assignment create `
  --role "Cognitive Services OpenAI User" `
  --assignee-object-id $principalId `
  --scope $aiResourceId
```

### Step 3: Verify

Check the LiteLLM logs to confirm authentication is working:

```powershell
az containerapp logs show `
  --name ca-litellm-<env-name> `
  --resource-group rg-<env-name> `
  --follow
```

You should see successful model requests without any authentication errors.

## Implementation Details

### Files Modified

1. **infra/main.bicep**
   - Added `useManagedIdentity` parameter (default: false)
   - Made `azureApiKey` parameter optional with empty string default
   - Updated litellmConfig to include `enable_azure_ad_token_refresh: true`
   - Pass `useManagedIdentity` to litellm module

2. **infra/app/litellm.bicep**
   - Added `useManagedIdentity` parameter
   - Conditional system-assigned managed identity creation
   - Conditional secret creation (only creates `azure-api-key` secret when not using managed identity)
   - Conditional environment variable (only sets `AZURE_API_KEY` when not using managed identity)

3. **infra/main.parameters.json**
   - Added `useManagedIdentity` parameter mapping to `USE_MANAGED_IDENTITY` environment variable
   - Made `azureApiKey` optional with empty string default

4. **litellm-config.yaml**
   - Added `enable_azure_ad_token_refresh: true` to litellm_settings
   - This enables automatic fallback to DefaultAzureCredential when API key is not provided

5. **azure.yaml**
   - Added `useManagedIdentity` parameter with boolean type and false default
   - Made `azureApiKey` optional with empty string default

### How LiteLLM Authenticates

With `enable_azure_ad_token_refresh: true`, LiteLLM follows this authentication flow:

1. **Check for API key**: If `AZURE_API_KEY` environment variable exists and is not empty, use it
2. **Fall back to DefaultAzureCredential**: If no API key, try:
   - Environment variables (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)
   - Managed Identity (automatically available in Container Apps) ✅
   - Azure CLI credentials
   - Other Azure identity sources

In our implementation, when `useManagedIdentity=true`:
- The container app gets a system-assigned managed identity
- No `AZURE_API_KEY` environment variable is set
- LiteLLM automatically uses DefaultAzureCredential
- DefaultAzureCredential discovers the managed identity
- Azure provides temporary tokens transparently

## Benefits of Managed Identity

✅ **No secrets to manage**: No API keys stored in configuration or secrets  
✅ **Automatic token rotation**: Azure handles token refresh transparently  
✅ **Audit trail**: All API calls are associated with the managed identity in Azure logs  
✅ **Principle of least privilege**: Grant only necessary permissions via RBAC  
✅ **Production best practice**: Recommended by Microsoft for Azure-to-Azure authentication  
✅ **Zero-trust security**: No long-lived credentials that could be compromised  

## Troubleshooting

### "Access Denied" Errors

**Problem**: LiteLLM shows 401/403 errors when accessing Azure AI models.

**Solution**: Verify the managed identity has the correct role assignment:
```powershell
az role assignment list `
  --assignee $principalId `
  --query "[?roleDefinitionName=='Cognitive Services OpenAI User']"
```

### No Managed Identity Created

**Problem**: Container app doesn't have a managed identity.

**Solution**: Verify `useManagedIdentity=true` was passed during deployment. Redeploy if needed:
```bash
azd env set USE_MANAGED_IDENTITY true
azd deploy
```

### Still Using API Key

**Problem**: LiteLLM is still using API key even though managed identity is enabled.

**Solution**: Ensure `AZURE_API_KEY` environment variable is empty or not set. Check the container app configuration:
```powershell
az containerapp show `
  --name ca-litellm-<env-name> `
  --resource-group rg-<env-name> `
  --query properties.template.containers[0].env
```

## Switching Between Modes

You can switch authentication modes by updating the deployment:

### Switch to Managed Identity

```bash
azd env set USE_MANAGED_IDENTITY true
azd env set AZURE_API_KEY ""
azd deploy
```

Then grant role assignment as described above.

### Switch to API Key

```bash
azd env set USE_MANAGED_IDENTITY false
azd env set AZURE_API_KEY "your-api-key"
azd deploy
```

## Security Comparison

| Aspect | API Key | Managed Identity |
|--------|---------|------------------|
| **Credential Storage** | Stored as secret in Container Apps | No credential storage needed |
| **Rotation** | Manual rotation required | Automatic token rotation |
| **Exposure Risk** | Key could be leaked/exposed | No long-lived credentials |
| **Audit Trail** | Generic API key usage | Identity-specific audit logs |
| **Setup Complexity** | Simple - just provide key | Requires role assignment |
| **Production Ready** | Acceptable | Recommended ✅ |

## References

- [Azure Managed Identities Documentation](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
- [LiteLLM Azure Authentication](https://docs.litellm.ai/docs/providers/azure#azure-ad-token-refresh---defaultazurecredential)
- [Azure Container Apps Managed Identity](https://learn.microsoft.com/azure/container-apps/managed-identity)
- [Azure OpenAI RBAC Roles](https://learn.microsoft.com/azure/ai-services/openai/how-to/role-based-access-control)
