targetScope = 'resourceGroup'

param apimName string
param foundryAccountName string
param foundryProjectName string
param agentName string
param apiName string
param apiPath string
param displayName string
param productName string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    apiType: 'http'
    displayName: displayName
    path: apiPath
    protocols: ['https']
    serviceUrl: 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectName}/agents/${agentName}/endpoint/protocols/openai'
    subscriptionRequired: true
    type: 'http'
  }
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: api
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

resource policy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies><inbound><base /><authentication-managed-identity resource="https://ai.azure.com" /><set-query-parameter name="api-version" exists-action="override"><value>v1</value></set-query-parameter><set-body>@{var body = context.Request.Body.As&lt;Newtonsoft.Json.Linq.JObject&gt;(preserveContent: true); body.Remove("tools"); body.Remove("tool_choice"); body.Remove("parallel_tool_calls"); return body.ToString();}</set-body></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>
'''
  }
}

resource product 'Microsoft.ApiManagement/service/products@2024-06-01-preview' existing = {
  parent: apim
  name: productName
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: product
  name: api.name
}

resource logger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' existing = {
  parent: apim
  name: 'applicationinsights'
}

resource diagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: false
    loggerId: logger.id
    metrics: true
    verbosity: 'information'
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
  }
}

output baseUrl string = '${apim.properties.gatewayUrl}/${apiPath}'
