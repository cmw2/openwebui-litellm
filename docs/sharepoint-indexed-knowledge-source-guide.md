# SharePoint Indexed Knowledge Source for Azure AI Search

Use this guide when you already have:

- A SharePoint document library containing approved source content.
- An Azure AI Search service.
- Microsoft Foundry model access when vector embeddings are required.

It describes the **Indexed SharePoint knowledge source** path. This preview
feature creates and owns the Search data source, skillset, index, and indexer.
Do not create competing indexers for the same managed knowledge source.

> [!IMPORTANT]
> Indexed SharePoint knowledge sources and agentic retrieval are preview
> features. They are not covered by an SLA and are not automatically approved
> for production or regulated workloads.

## Before you begin

Ensure the people performing setup have the following resource-level roles.

| Resource | Required role or permission |
|---|---|
| Azure AI Search service | **Search Service Contributor** and **Search Index Data Contributor** for the identity that creates or updates the knowledge source. |
| Microsoft Foundry resource/account | **Foundry User** for the identity that deploys the embedding model; sufficient quota for the selected model. |
| Azure AI Search and Foundry resources | **Owner**, **User Access Administrator**, or equivalent role-assignment authority for the identity that grants runtime roles. |
| SharePoint site / Microsoft Entra ID | Delegated `Sites.FullControl.All` and appropriate SharePoint/Entra authority for the one-time operator that grants the ingestion application access to the selected site. |

## 1. Choose the initial scope

Start with one library on one site and non-sensitive test documents. This
initial POC copies content into Azure AI Search and does **not** configure ACL
ingestion or per-user query-time enforcement.

For a later permission-aware phase, choose deliberately between:

- **Indexed SharePoint with ACL ingestion**: Azure AI Search ingests supported
  SharePoint permission metadata and evaluates it at query time when the
  application supplies the user's authorization context. This remains preview
  and has item/group/permission-model limitations.
- **Remote SharePoint knowledge source / Copilot Retrieval**: Search queries
  SharePoint at retrieval time rather than copying content into an index, so
  SharePoint enforces the user's access directly.

Do not treat either option as an automatic upgrade to the initial no-ACL POC;
review the supported permission model, user-token propagation, and preview
constraints before enabling it.

## 2. Prepare Azure AI Search and Microsoft Foundry

1. Use an Azure AI Search service on Basic SKU or higher.
2. Enable its system-assigned managed identity.
3. Enable Microsoft Entra/RBAC data-plane access under **Security + Networking**
   > **Keys** > **API access control**. Choose **Role-based access control**,
   or **Both** during an API-key transition.
4. Deploy an embedding model in Foundry. The validated POC example is:

   ```text
   Model: text-embedding-3-large
   Deployment name: text-embedding-3-large
   ```

Record the deployment name because the Indexed SharePoint knowledge source
references it as the embedding model.

## 3. Configure the SharePoint ingestion application

Create a single-tenant Entra application registration for the Search indexer.

1. Add Microsoft Graph **application** permission `Sites.Selected`.
2. Obtain tenant administrator consent for `Sites.Selected`.

This keeps the runtime application scoped to the selected site.

The operator who grants the site permission is not the runtime application.
The operator needs delegated `Sites.FullControl.All` and appropriate
SharePoint/Entra administrative authority for the one-time grant.

### Configure secretless federation

Use a federated identity credential on the ingestion application instead of a
client secret.

1. On the Azure AI Search service, record both identity values:
   - **Principal (object) ID**
   - **Client ID**
2. In Microsoft Entra ID, open the ingestion application registration.
3. Select **Certificates & secrets** > **Federated credentials** > **Add
   credential**.
4. Create an **Other issuer** federated credential with:

   | Field | Value |
   |---|---|
   | Issuer | `https://login.microsoftonline.com/<tenant-id>/v2.0` |
   | Subject | The Search managed identity **principal (object) ID** |
   | Audience | `api://AzureADTokenExchange` |
   | Name | A descriptive name such as `search-service-mi` |

This lets Azure AI Search obtain an application token for the ingestion app
without a client secret.

Use the Search managed identity **client ID** in the knowledge-source
connection string as `FederatedCredentialApplicationId`.

## 4. Grant the site permission

The repository includes `set-sp-site-selected.ps1` for the one-time
site-level grant.

```powershell
.\set-sp-site-selected.ps1 `
  -SharePointDomain "<tenant-sharepoint-domain>" `
  -SitePath "/sites/<site-name>" `
  -AppClientId "<ingestion-app-client-id>" `
  -AppDisplayName "<ingestion-app-name>" `
  -Roles read
```

Omit `-UseDeviceAuthentication` on a normal desktop PowerShell session; add it
only when an interactive browser window is unavailable.

Record the returned site ID and permission ID. They are needed for audit and
revocation.

## 5. Create the Indexed SharePoint knowledge source

The knowledge source requires:

```text
SharePointOnlineEndpoint=https://<sharepoint-host>/sites/<site>;
ApplicationId=<ingestion-app-client-id>;
TenantId=<tenant-id>;
FederatedCredentialApplicationId=<search-managed-identity-client-id>
```

Use:

- `kind: indexedSharePoint`
- `containerName: defaultSiteLibrary`
- `contentExtractionMode: minimal` for a simple text/embedding POC
- `networkAccessMode: public` unless you have validated the extra
  private-mode prerequisites
- an embedding deployment such as `text-embedding-3-large`

### Option A: Foundry portal

In your Foundry project, use the Foundry IQ/knowledge workflow to
add an **Indexed SharePoint** source. Enter the SharePoint connection values
and select the embedding deployment. This portal flow creates the knowledge
source and its associated knowledge base together.

Wait for ingestion to complete before attaching the knowledge base to an agent.
Review generated Search resources only for troubleshooting; the managed
knowledge source owns them.

### Option B: Automation-first

Use the checked-in definition and script:

```powershell
.\scripts\apply_search_knowledge_source.ps1 `
  -SearchEndpoint "https://<search-name>.search.windows.net" `
  -SharePointSiteUrl "https://<sharepoint-host>/sites/<site>" `
  -IndexerApplicationId "<ingestion-app-client-id>" `
  -TenantId "<tenant-id>" `
  -SearchManagedIdentityClientId "<search-managed-identity-client-id>"
```

The script applies
`infra/search/knowledge-sources/poppy-sharepoint-indexed.json` idempotently
with an Entra Search data-plane token. It does not store a SharePoint secret.

## 6. Validate ingestion

Poll the status endpoint until the latest run completes:

```http
GET https://<search-name>.search.windows.net/knowledgesources/<source-name>/status?api-version=2026-08-01-preview
Authorization: Bearer <Search data-plane token>
```

Success criteria:

- `synchronizationStatus` is `active`.
- The latest synchronization has `itemsUpdatesFailed: 0`.
- The expected document count was processed.

Common failure signals:

| Symptom | Likely cause | Action |
|---|---|---|
| SharePoint `accessDenied` | Missing site-level grant or wrong app identity | Verify `Sites.Selected`, tenant consent, and the explicit site `read` grant. |
| Token/federation failure | Wrong issuer, subject, audience, or identity identifier | Confirm the subject is Search MI **object ID** and the connection string uses Search MI **client ID**. |
| Embedding authorization failure | Search MI lacks Foundry access | Grant **Cognitive Services User** on the model resource. |
| Source never finds content | Wrong site/library scope or unsupported file type | Test a simple supported file in the target library. |
| Private-mode failure | Unsupported SKU/network path | Use public mode for the POC or validate the documented private-mode prerequisites. |

## 7. Preserve original SharePoint links

The generated indexer initially maps a Graph-style path to `doc_url`. To keep
canonical SharePoint web URLs in the managed index, apply the checked-in native
indexer override and run a full reindex:

```powershell
.\scripts\apply_sharepoint_indexer_citation_mapping.ps1 `
  -SearchEndpoint "https://<search-name>.search.windows.net"
```

The override maps:

```text
metadata_spo_item_weburi -> doc_url
```

This is an indexer configuration change, not a document-by-document patch.
After changing field mappings, reset and rerun the indexer so existing
documents are reprocessed.

## 8. Confirm or create a knowledge base

The knowledge base is the reusable retrieval object used by Foundry IQ.

### Foundry portal

The Foundry portal flow already created the associated knowledge base. Confirm
it exists and use that portal-created knowledge base; do not create a
duplicate.

### Automation-first

```powershell
.\scripts\apply_search_knowledge_base.ps1 `
  -SearchEndpoint "https://<search-name>.search.windows.net"
```

The included definition sets practical POC defaults: 45-second maximum runtime,
8 output documents, 12,000 token maximum output, and minimal retrieval
reasoning because no answer-synthesis model is configured.

## 9. Citation expectations

The knowledge-base retrieve API can expose canonical SharePoint URLs as
`sourceData.doc_url` when `includeReferenceSourceData` is enabled on the
indexed SharePoint source parameter.

Current Foundry-generated automatic citation panels can still show generic
Search/MCP links. If using the Foundry IQ MCP agent in this repository, its
instructions render a separate SharePoint document-library link in the answer
body to give users a usable source link.

## Relevant Microsoft documentation

- [Create an Indexed SharePoint knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-indexed)
- [SharePoint in Microsoft 365 indexer](https://learn.microsoft.com/azure/search/search-how-to-index-sharepoint-online)
- [Ingest SharePoint permission metadata](https://learn.microsoft.com/azure/search/search-indexer-sharepoint-access-control-lists)
- [Query-time access control in Azure AI Search](https://learn.microsoft.com/azure/search/search-query-access-control-rbac-enforcement)
- [Configure Azure AI Search managed identities](https://learn.microsoft.com/azure/search/search-how-to-managed-identities)
- [Selected permissions in SharePoint and OneDrive](https://learn.microsoft.com/graph/permissions-selected-overview)
- [Create a knowledge base](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-create-knowledge-base)
- [Query a knowledge base through REST or MCP](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve)
- [Foundry IQ knowledge-base agent connection](https://learn.microsoft.com/azure/foundry/agents/how-to/foundry-iq-connect)
- [Azure Government feature availability](https://learn.microsoft.com/azure/security/fundamentals/feature-availability)
