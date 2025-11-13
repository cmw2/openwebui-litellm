# Azure Developer CLI (azd) Repository Structure

This repository has been restructured to follow Azure Developer CLI conventions with Azure Container Apps as the primary deployment target.

## 📁 Repository Structure

```
openwebui-litellm/
├── azure.yaml                      # azd configuration (defines services and hooks)
├── docker-compose.yml              # Local development with Docker Compose
├── litellm-config.yaml            # LiteLLM model configuration
├── .env.template                   # Environment variables template
│
├── infra/                          # Infrastructure as Code (Bicep)
│   ├── main.bicep                 # Main orchestration
│   ├── main.parameters.json       # Parameter mappings
│   ├── core/                      # Core infrastructure modules
│   │   ├── monitoring.bicep       # Log Analytics workspace
│   │   ├── storage.bicep          # Azure Files storage
│   │   └── container-apps-env.bicep # Container Apps Environment
│   └── app/                       # Application modules
│       ├── litellm.bicep          # LiteLLM Container App
│       └── openwebui.bicep        # Open WebUI Container App
│
└── docs/                           # Documentation
    ├── README.md                  # Main readme (Azure primary)
    ├── SETUP-AZURE-CONTAINER-APPS.md  # Detailed Azure guide
    ├── SETUP-LOCAL.md             # Local Docker Compose guide
    ├── DEPLOYMENT-PLAN.md         # Technical implementation details
    ├── SETUP-LINUX.md             # Legacy Linux setup
    └── SETUP-WINDOWS-SERVER.md    # Legacy Windows setup
```

## 🎯 Primary vs Secondary Deployment Methods

### Primary: Azure Container Apps (via azd)

**Benefits:**
- One-command deployment: `azd up`
- Production-ready with HTTPS, auto-scaling, monitoring
- Managed infrastructure and updates
- Built-in security features

**Use when:**
- Deploying to production or shared environments
- Need high availability and auto-scaling
- Want managed infrastructure
- Require HTTPS and secure endpoints

**Cost:** ~$25-50/month (consumption-based pricing)

### Secondary: Docker Compose (Local)

**Benefits:**
- Quick local testing
- No Azure costs
- Full control over environment
- Faster iteration during development

**Use when:**
- Developing or testing changes
- Learning the stack
- Limited budget (free on your hardware)
- Offline development needed

**Cost:** Free (uses your local resources)

## 🚀 Quick Commands

### Azure Deployment (Primary)

```bash
# First-time setup and deployment
azd auth login
azd up

# Subsequent deployments
azd deploy

# View logs
azd monitor --logs

# Tear down
azd down
```

### Local Development (Secondary)

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## 📚 Documentation Guide

| Document | Purpose | Audience |
|----------|---------|----------|
| **README.md** | Quick start and overview | Everyone |
| **SETUP-AZURE-CONTAINER-APPS.md** | Detailed Azure deployment | Azure deployers |
| **SETUP-LOCAL.md** | Docker Compose development | Local developers |
| **DEPLOYMENT-PLAN.md** | Technical architecture details | DevOps/Architects |

## 🔄 Migration from Legacy Setup

If you were using the old Docker-only setup:

1. **Your `.env` file still works** - Same format
2. **Your `litellm-config.yaml` still works** - Same format
3. **To deploy to Azure:** Just run `azd up`
4. **To continue local dev:** Continue using `docker-compose`

No breaking changes to existing local development workflows!

## 🛠️ Development Workflow

### Recommended Flow

1. **Develop locally** with Docker Compose
   ```bash
   docker-compose up -d
   # Make changes, test locally
   ```

2. **Test in Azure** when ready
   ```bash
   azd deploy
   # Test in cloud environment
   ```

3. **Promote to production** environment
   ```bash
   # Create production environment
   azd env new production
   azd up
   ```

### Configuration Management

- **Shared config:** `litellm-config.yaml` (same for both)
- **Local env:** `.env` (for Docker Compose)
- **Azure env:** `.azure/<env-name>/.env` (for azd)

## 🔐 Security Considerations

### Local Development
- Environment variables in `.env` (not committed)
- Local network only
- No HTTPS (http://localhost)

### Azure Deployment
- Secrets stored in Container Apps environment
- Managed identities where possible
- HTTPS by default with Azure-managed certificates
- LiteLLM not exposed to internet (internal only)

## 📊 Comparison Matrix

| Feature | Local Docker | Azure Container Apps |
|---------|--------------|---------------------|
| **Setup time** | 2 minutes | 5-10 minutes (first time) |
| **Deployment** | `docker-compose up` | `azd up` |
| **Access** | localhost:3000 | HTTPS URL |
| **Scaling** | Manual | Auto (1-5 replicas) |
| **Storage** | Docker volume | Azure Files |
| **Monitoring** | Docker logs | Log Analytics |
| **Cost** | Free | ~$25-50/month |
| **HA/DR** | None | Multi-replica |
| **Security** | Local only | Enterprise-grade |

## 🎓 Learning Path

1. **Start local** - Use Docker Compose to understand the stack
2. **Deploy to Azure** - Use `azd up` for your first Azure deployment
3. **Explore monitoring** - Use `azd monitor` and Azure Portal
4. **Customize** - Modify Bicep files for your requirements
5. **Automate** - Integrate with CI/CD pipelines

## 🤝 Contributing

When contributing:
- Bicep files follow Azure best practices
- Use latest API versions
- Include comments for complex logic
- Update documentation for any changes
- Test both local and Azure deployments

## 📖 Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
