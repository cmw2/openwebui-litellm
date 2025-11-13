# Quick Start Guide

Choose your deployment method:

## 🚀 Azure (Production) - 2 Commands

```bash
azd auth login
azd up
```

You'll be prompted for:
- Azure subscription & location
- Environment name (e.g., "dev", "prod")
- Azure AI Foundry credentials (API key, base URL, version)
- LiteLLM master key (generate a secure random string)

**Done!** Access your deployment at the HTTPS URL shown.

---

## 💻 Local (Development) - 3 Commands

```bash
cp .env.template .env
# Edit .env with your Azure AI credentials
docker-compose up -d
```

**Done!** Access at http://localhost:3000

---

## 📖 Need More Details?

- **Azure deployment:** [SETUP-AZURE-CONTAINER-APPS.md](SETUP-AZURE-CONTAINER-APPS.md)
- **Local development:** [SETUP-LOCAL.md](SETUP-LOCAL.md)
- **Architecture:** [AZD-STRUCTURE.md](AZD-STRUCTURE.md)

---

## ⚙️ Configuration

Both methods use the same `litellm-config.yaml` for model definitions.

Add your Azure AI Foundry models:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: ${AZURE_API_BASE}
      api_key: ${AZURE_API_KEY}
      api_version: ${AZURE_API_VERSION}
```

---

## 🆘 Troubleshooting

**Azure:**
```bash
azd monitor --logs
```

**Local:**
```bash
docker-compose logs -f
```

---

That's it! 🎉
