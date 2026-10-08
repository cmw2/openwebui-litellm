[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectResourceId,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^/]+$')]
    [string]$SearchEndpoint,

    [string]$KnowledgeBaseName = 'poppy-sharepoint-kb',

    [string]$ConnectionName = 'poppy-sharepoint-kb-mcp',

    [string]$DefinitionPath = (Join-Path $PSScriptRoot '..\infra\foundry\connections\poppy-sharepoint-kb-mcp.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
    throw "Foundry IQ connection definition was not found: $DefinitionPath"
}

$definition = Get-Content -LiteralPath $DefinitionPath -Raw
$definition = $definition -replace '__SEARCH_ENDPOINT__', $SearchEndpoint.TrimEnd('/')
$definition = $definition -replace '__KNOWLEDGE_BASE_NAME__', $KnowledgeBaseName
$requestBodyPath = Join-Path $env:TEMP "foundry-iq-connection-$([guid]::NewGuid()).json"

try {
    Set-Content -LiteralPath $requestBodyPath -Value $definition -Encoding utf8NoBOM
    $uri = "https://management.azure.com$ProjectResourceId/connections/$ConnectionName`?api-version=2025-10-01-preview"
    $category = az rest --method put --url $uri --headers 'Content-Type=application/json' `
        --body "@$requestBodyPath" --query properties.category --output tsv

    if ($category -ne 'RemoteTool') {
        throw "Foundry IQ connection update returned unexpected category: $category"
    }

    Write-Output "Created or updated Foundry IQ connection: $ConnectionName"
}
finally {
    if (Test-Path -LiteralPath $requestBodyPath) {
        Remove-Item -LiteralPath $requestBodyPath -Force
    }
}
