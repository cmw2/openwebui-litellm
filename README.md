# Open WebUI + LiteLLM with Azure AI Foundry

This setup runs Open WebUI with LiteLLM as a proxy to your Azure AI Foundry deployed models.

## Setup Instructions

### 1. Configure Azure Credentials

Copy `.env.template` to `.env` and fill in your Azure AI Foundry details:

```bash
cp .env.template .env
```

Then edit `.env` with your actual values:
- `AZURE_API_KEY`: Your Azure API key
- `AZURE_API_BASE`: Your Azure endpoint (e.g., https://your-project.openai.azure.com/)
- `AZURE_API_VERSION`: API version (typically `2024-08-01-preview`)

### 2. Update Model Deployments

Edit `litellm-config.yaml` to add all your deployed models. Since you name deployments the same as the model, just add entries like:

```yaml
- model_name: gpt-4-turbo
  litellm_params:
    model: azure/gpt-4-turbo
    api_base: ${AZURE_API_BASE}
    api_key: ${AZURE_API_KEY}
    api_version: ${AZURE_API_VERSION}
```

### 3. Start the Services

Make sure you're using your lab Docker context:

```powershell
docker context use lab
```

Then start the containers:

```powershell
docker-compose up -d
```

### 4. Access Open WebUI

Open your browser to http://localhost:3000

On first access, you'll be prompted to create an admin account.

### 5. Use Your Models

All models configured in `litellm-config.yaml` will be available in Open WebUI's model dropdown.

## Managing the Stack

**View logs:**
```powershell
docker-compose logs -f
```

**Stop services:**
```powershell
docker-compose down
```

**Restart services:**
```powershell
docker-compose restart
```

**Update to latest versions:**
```powershell
docker-compose pull
docker-compose up -d
```

## Troubleshooting

**LiteLLM container not starting:**
- Check `.env` file has correct Azure credentials
- Check `litellm-config.yaml` syntax

**Open WebUI can't connect to models:**
- Verify LiteLLM is running: `docker-compose logs litellm`
- Check LiteLLM is accessible: http://localhost:4000/health

**Models not appearing:**
- Check model names in `litellm-config.yaml` match your Azure deployments
- View LiteLLM logs for any errors
