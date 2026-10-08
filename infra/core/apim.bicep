targetScope = 'resourceGroup'

@description('Location for API Management.')
param location string

@description('Tags to apply to API Management.')
param tags object = {}

@description('Name of the API Management instance.')
param apimName string

@description('Publisher organization displayed in API Management.')
param publisherName string

@description('Publisher email displayed in API Management.')
param publisherEmail string

@description('Existing Azure AI Services Foundry account name.')
param foundryAccountName string

@description('Existing Foundry project name.')
param foundryProjectName string

@description('Foundry prompt agent exposed by this Responses facade.')
param promptAgentName string = 'openwebui-prompt-agent'

@description('Primary key for the API-scoped LiteLLM subscription.')
@secure()
param litellmSubscriptionPrimaryKey string

@description('Application Insights connection string for APIM diagnostics.')
@secure()
param appInsightsConnectionString string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    publicNetworkAccess: 'Enabled'
    developerPortalStatus: 'Disabled'
    legacyPortalStatus: 'Disabled'
    natGatewayState: 'Enabled'
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
    }
  }
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: foundryAccountName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-12-01' existing = {
  parent: foundryAccount
  name: foundryProjectName
}

resource foundryUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundryProject
  name: guid(foundryProject.id, apim.id, 'Foundry User')
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '53ca6127-db72-4b80-b1b0-d745d6d5456d'
    )
  }
}

// Presents the agent's OpenAI Responses endpoint through APIM so gateway
// clients do not need to supply the Foundry-specific API version or token.
resource promptAgentResponsesApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'foundry-prompt-agent-responses'
  properties: {
    apiType: 'http'
    displayName: 'Foundry Prompt Agent Responses'
    description: 'OpenAI Responses facade for the OpenWebUI prompt agent.'
    path: 'foundry-prompt-agent'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectName}/agents/${promptAgentName}/endpoint/protocols/openai'
    subscriptionRequired: true
    type: 'http'
  }

}

resource litellmFoundryAgentsProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  parent: apim
  name: 'litellm-foundry-agents'
  properties: {
    displayName: 'LiteLLM Foundry Agents'
    description: 'APIM product containing Foundry agent Responses façades used only by LiteLLM.'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource promptAgentProductApi 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: litellmFoundryAgentsProduct
  name: promptAgentResponsesApi.name
}

resource promptAgentResponsesOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: promptAgentResponsesApi
  name: 'create-response'
  properties: {
    displayName: 'Create Response'
    method: 'POST'
    urlTemplate: '/responses'
    responses: [
      {
        statusCode: 200
        description: 'Successful agent response.'
      }
    ]
  }
}

resource promptAgentResponsesPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: promptAgentResponsesApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="https://ai.azure.com" />
    <set-query-parameter name="api-version" exists-action="override">
      <value>v1</value>
    </set-query-parameter>
    <set-body>@{
      var body = context.Request.Body.As&lt;Newtonsoft.Json.Linq.JObject&gt;(preserveContent: true);
      body.Remove("tools");
      body.Remove("tool_choice");
      body.Remove("parallel_tool_calls");
      return body.ToString();
    }</set-body>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger for Foundry prompt agent traffic.'
    credentials: {
      connectionString: appInsightsConnectionString
    }
  }
}

resource promptAgentResponsesDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: promptAgentResponsesApi
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: false
    loggerId: appInsightsLogger.id
    metrics: true
    verbosity: 'information'
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: [
          'Content-Type'
          'User-Agent'
        ]
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: [
          'Content-Type'
        ]
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: [
          'Content-Type'
        ]
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: [
          'Content-Type'
        ]
        body: {
          bytes: 8192
        }
      }
    }
  }
}

resource litellmPromptAgentSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: 'litellm-foundry-prompt-agent-responses'
  properties: {
    displayName: 'LiteLLM Foundry Prompt Agent Responses'
    scope: '/products/${litellmFoundryAgentsProduct.name}'
    state: 'active'
    allowTracing: false
    primaryKey: litellmSubscriptionPrimaryKey
  }
}

output apimId string = apim.id
output apimName string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output portalUrl string = 'https://portal.azure.com/#resource${apim.id}/overview'
output principalId string = apim.identity.principalId
output promptAgentResponsesUrl string = '${apim.properties.gatewayUrl}/foundry-prompt-agent/responses'
output litellmPromptAgentSubscriptionId string = litellmPromptAgentSubscription.name
