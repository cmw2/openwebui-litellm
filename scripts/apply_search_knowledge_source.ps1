[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^/]+$')]
    [string]$SearchEndpoint,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^/]+/sites/[^/]+$')]
    [string]$SharePointSiteUrl,

    [Parameter(Mandatory)]
    [guid]$IndexerApplicationId,

    [Parameter(Mandatory)]
    [guid]$TenantId,

    [Parameter(Mandatory)]
    [guid]$SearchManagedIdentityClientId,

    [string]$KnowledgeSourceName = 'poppy-sharepoint-indexed',

    [string]$DefinitionPath = (Join-Path $PSScriptRoot '..\infra\search\knowledge-sources\poppy-sharepoint-indexed.json'),

    [string]$DnsOverride
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
    throw "Knowledge source definition was not found: $DefinitionPath"
}

$definition = Get-Content -LiteralPath $DefinitionPath -Raw
$definition = $definition -replace '__SHAREPOINT_SITE_URL__', $SharePointSiteUrl
$definition = $definition -replace '__INDEXER_APPLICATION_ID__', $IndexerApplicationId
$definition = $definition -replace '__TENANT_ID__', $TenantId
$definition = $definition -replace '__SEARCH_MANAGED_IDENTITY_CLIENT_ID__', $SearchManagedIdentityClientId
$definitionObject = $definition | ConvertFrom-Json

if ($definitionObject.name -ne $KnowledgeSourceName) {
    throw 'The rendered knowledge source name does not match KnowledgeSourceName.'
}

$token = az account get-access-token `
    --resource 'https://search.azure.com' `
    --query accessToken `
    --output tsv

if (-not $token) {
    throw 'Could not acquire an Azure AI Search data-plane token.'
}

$requestBodyPath = Join-Path $env:TEMP "knowledge-source-$([guid]::NewGuid()).json"

try {
    Set-Content -LiteralPath $requestBodyPath -Value $definition -Encoding utf8NoBOM

    $baseUri = $SearchEndpoint.TrimEnd('/')
    $uri = "$baseUri/knowledgesources/$KnowledgeSourceName`?api-version=2026-08-01-preview"
    $curlArguments = @(
        '--silent'
        '--show-error'
        '--fail-with-body'
        '--request'
        'PUT'
        '--header'
        "Authorization: Bearer $token"
        '--header'
        'Content-Type: application/json'
        '--data-binary'
        "@$requestBodyPath"
    )

    if ($DnsOverride) {
        $hostName = ([uri]$baseUri).Host
        $curlArguments += @('--resolve', "$hostName`:443:$DnsOverride")
    }

    $curlArguments += $uri
    $response = & curl.exe @curlArguments

    if ($LASTEXITCODE -ne 0) {
        throw "Knowledge source create or update failed with curl exit code $LASTEXITCODE."
    }

    $knowledgeSource = $response | ConvertFrom-Json
    if ($knowledgeSource.name -ne $KnowledgeSourceName) {
        throw 'Azure AI Search returned an unexpected knowledge source name.'
    }

    Write-Output "Created or updated knowledge source: $KnowledgeSourceName"
}
finally {
    if (Test-Path -LiteralPath $requestBodyPath) {
        Remove-Item -LiteralPath $requestBodyPath -Force
    }
}
