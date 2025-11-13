# Local Development with Docker Compose

This guide covers running Open WebUI + LiteLLM locally using Docker Compose for development and testing.

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Azure AI Foundry** with deployed models
- Access to Azure AI Foundry credentials

## Quick Start

### 1. Configure Environment Variables

Copy the environment template:

```bash
cp .env.template .env
```

Edit `.env` with your Azure AI Foundry credentials:

```bash
# Azure AI Foundry Configuration
AZURE_API_KEY=your-azure-api-key-here
AZURE_API_BASE=https://your-project.openai.azure.com/
AZURE_API_VERSION=2024-08-01-preview

# LiteLLM Master Key
LITELLM_MASTER_KEY=sk-your-secure-random-key
```

### 2. Configure Models

Edit `litellm-config.yaml` to add your deployed models:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: ${AZURE_API_BASE}
      api_key: ${AZURE_API_KEY}
      api_version: ${AZURE_API_VERSION}

  - model_name: gpt-4o-mini
    litellm_params:
      model: azure/gpt-4o-mini
      api_base: ${AZURE_API_BASE}
      api_key: ${AZURE_API_KEY}
      api_version: ${AZURE_API_VERSION}
```

Add entries for each model deployed in your Azure AI Foundry project.

### 3. Start the Services

```bash
docker-compose up -d
```

This will:
- Start LiteLLM on port 4000 (internal only)
- Start Open WebUI on port 3000
- Create a Docker volume for persistent data
- Create a bridge network for container communication

### 4. Access Open WebUI

Open your browser to: http://localhost:3000

On first access, you'll be prompted to create an admin account.

## Managing the Local Stack

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f litellm
docker-compose logs -f open-webui
```

### Stop Services

```bash
docker-compose down
```

To also remove the data volume:
```bash
docker-compose down -v
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart litellm
```

### Update to Latest Versions

```bash
docker-compose pull
docker-compose up -d
```

### Check Service Status

```bash
docker-compose ps
```

## Configuration

### Docker Compose Structure

The `docker-compose.yml` defines:

**LiteLLM Service:**
- Image: `ghcr.io/berriai/litellm:main-latest`
- Port: 4000 (internal)
- Config: Loaded from inline config in docker-compose.yml
- Environment: Azure AI credentials from `.env`

**Open WebUI Service:**
- Image: `ghcr.io/open-webui/open-webui:main`
- Port: 3000 (exposed to host)
- Storage: Docker volume mounted at `/app/backend/data`
- Environment: LiteLLM URL configured as `http://litellm:4000/v1`

### Network Architecture

```
┌─────────────────────┐
│   Your Browser      │
│   localhost:3000    │
└──────────┬──────────┘
           │
           │ HTTP
           ▼
┌─────────────────────┐
│   Open WebUI        │
│   Container         │
│   Port 3000         │
└──────────┬──────────┘
           │
           │ Internal Network
           │ http://litellm:4000
           ▼
┌─────────────────────┐
│   LiteLLM           │
│   Container         │
│   Port 4000         │
└──────────┬──────────┘
           │
           │ HTTPS
           ▼
┌─────────────────────┐
│   Azure AI Foundry  │
│   OpenAI Models     │
└─────────────────────┘
```

## Troubleshooting

### LiteLLM Container Not Starting

**Check logs:**
```bash
docker-compose logs litellm
```

**Common issues:**
- Invalid Azure credentials in `.env`
- Syntax errors in `litellm-config.yaml`
- Model names don't match Azure deployments

**Solutions:**
1. Verify `.env` file has correct values
2. Validate YAML syntax in `litellm-config.yaml`
3. Check Azure AI Foundry for exact model deployment names

### Open WebUI Can't Connect to Models

**Test LiteLLM health:**
```bash
curl http://localhost:4000/health
```

**Check LiteLLM API:**
```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

**Common issues:**
- LiteLLM not running
- Incorrect `OPENAI_API_BASE_URL` in Open WebUI
- Network connectivity between containers

**Solutions:**
1. Ensure LiteLLM is running: `docker-compose ps`
2. Verify network is created: `docker network ls`
3. Check Open WebUI environment variables: `docker-compose config`

### Models Not Appearing

**Check model list:**
```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

**Common issues:**
- Model names in config don't match Azure deployments
- Azure API credentials are incorrect
- LiteLLM can't reach Azure endpoint

**Solutions:**
1. Verify model names in Azure AI Foundry
2. Test Azure credentials manually
3. Check LiteLLM logs for API errors

### Port Already in Use

**Error:** `Bind for 0.0.0.0:3000 failed: port is already allocated`

**Solutions:**
1. Stop conflicting service
2. Change port in `docker-compose.yml`:
   ```yaml
   ports:
     - "3001:8080"  # Use different host port
   ```

### Data Not Persisting

**Check volume:**
```bash
docker volume ls
docker volume inspect openwebui-litellm_open-webui-data
```

**Solutions:**
1. Ensure volume is mounted: `docker-compose config`
2. Verify volume permissions
3. Check container logs for write errors

## Using a Remote Docker Host

If you have a remote Docker server (like the lab setup):

```bash
# List available contexts
docker context ls

# Switch to remote context
docker context use lab

# Deploy to remote host
docker-compose up -d

# Access via remote host
# Open WebUI: http://<remote-host>:3000
```

## Development Tips

### Testing Configuration Changes

After modifying `litellm-config.yaml`:
```bash
docker-compose restart litellm
docker-compose logs -f litellm
```

### Debugging LiteLLM

Enable detailed debug logs by modifying the command in `docker-compose.yml`:
```yaml
command: --config /app/config.yaml --detailed_debug
```

### Inspecting Containers

```bash
# Execute commands in container
docker-compose exec litellm /bin/sh
docker-compose exec open-webui /bin/bash

# View environment variables
docker-compose exec litellm env
```

### Backing Up Data

```bash
# Backup Open WebUI data
docker run --rm \
  -v openwebui-litellm_open-webui-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/openwebui-backup.tar.gz /data
```

### Restoring Data

```bash
# Restore Open WebUI data
docker run --rm \
  -v openwebui-litellm_open-webui-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/openwebui-backup.tar.gz -C /
```

## Differences from Azure Deployment

| Feature | Local Docker | Azure Container Apps |
|---------|--------------|---------------------|
| **Access** | http://localhost:3000 | HTTPS with auto certificate |
| **Storage** | Docker volume | Azure Files |
| **Scaling** | Manual | Auto-scaling (1-5 replicas) |
| **Monitoring** | Docker logs | Log Analytics workspace |
| **Security** | Local network | Managed identity, secrets |
| **Cost** | Free (your hardware) | ~$25-50/month |
| **High Availability** | No | Yes (multi-replica) |

## Next Steps

Once you've tested locally and are ready for production:

1. Review the [Azure deployment guide](SETUP-AZURE-CONTAINER-APPS.md)
2. Deploy to Azure with `azd up`
3. Configure custom domain and authentication
4. Set up monitoring and alerts

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
