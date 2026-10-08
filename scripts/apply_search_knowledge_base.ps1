[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^/]+$')]
    [string]$SearchEndpoint,

    [string]$KnowledgeBaseName = 'poppy-sharepoint-kb',

    [string]$DefinitionPath = (Join-Path $PSScriptRoot '..\infra\search\knowledge-bases\poppy-sharepoint-kb.json'),

    [string]$DnsOverride
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
    throw "Knowledge base definition was not found: $DefinitionPath"
}

$definition = (Get-Content -LiteralPath $DefinitionPath -Raw) `
    -replace '__KNOWLEDGE_BASE_NAME__', $KnowledgeBaseName
$definitionObject = $definition | ConvertFrom-Json

if ($definitionObject.name -ne $KnowledgeBaseName) {
    throw 'The rendered knowledge base definition has an unexpected name.'
}

$token = az account get-access-token `
    --resource 'https://search.azure.com' `
    --query accessToken `
    --output tsv

if (-not $token) {
    throw 'Could not acquire an Azure AI Search data-plane token.'
}

$requestBodyPath = Join-Path $env:TEMP "knowledge-base-$([guid]::NewGuid()).json"

try {
    Set-Content -LiteralPath $requestBodyPath -Value $definition -Encoding utf8NoBOM

    $baseUri = $SearchEndpoint.TrimEnd('/')
    $uri = "$baseUri/knowledgebases/$KnowledgeBaseName`?api-version=2026-08-01-preview"
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
        throw "Knowledge base create or update failed with curl exit code $LASTEXITCODE."
    }

    if ($response) {
        $knowledgeBase = $response | ConvertFrom-Json
        if ($knowledgeBase.name -and $knowledgeBase.name -ne $KnowledgeBaseName) {
            throw 'Azure AI Search returned an unexpected knowledge base name.'
        }
    }

    Write-Output "Created or updated knowledge base: $KnowledgeBaseName"
}
finally {
    if (Test-Path -LiteralPath $requestBodyPath) {
        Remove-Item -LiteralPath $requestBodyPath -Force
    }
}
