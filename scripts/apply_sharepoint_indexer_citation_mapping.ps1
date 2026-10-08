[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^/]+$')]
    [string]$SearchEndpoint,

    [string]$IndexerName = 'poppy-sharepoint-indexed-indexer',

    [string]$MappingPath = (Join-Path $PSScriptRoot '..\infra\search\indexer-overrides\poppy-sharepoint-indexed-citation-mapping.json'),

    [string]$DnsOverride
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MappingPath -PathType Leaf)) {
    throw "Indexer citation mapping was not found: $MappingPath"
}

$baseUri = $SearchEndpoint.TrimEnd('/')
$hostName = ([uri]$baseUri).Host
$token = az account get-access-token `
    --resource 'https://search.azure.com' `
    --query accessToken `
    --output tsv

if (-not $token) {
    throw 'Could not acquire an Azure AI Search data-plane token.'
}

function Invoke-SearchCurl {
    param([string[]]$Arguments)

    $curlArguments = @(
        '--silent'
        '--show-error'
        '--fail-with-body'
        '--header'
        "Authorization: Bearer $token"
    ) + $Arguments

    if ($DnsOverride) {
        $curlArguments += @('--resolve', "$hostName`:443:$DnsOverride")
    }

    & curl.exe @curlArguments
}

$indexerUri = "$baseUri/indexers/$IndexerName`?api-version=2026-08-01-preview"
$indexer = Invoke-SearchCurl -Arguments @($indexerUri) | ConvertFrom-Json
$mappings = @(Get-Content -LiteralPath $MappingPath -Raw | ConvertFrom-Json)
$mappedTargets = @($mappings.targetFieldName + 'url')
$fieldMappings = @($indexer.fieldMappings | Where-Object { $_.targetFieldName -notin $mappedTargets })
$indexer.fieldMappings = @($fieldMappings + $mappings)
$bodyPath = Join-Path $env:TEMP "sharepoint-indexer-$([guid]::NewGuid()).json"

try {
    $indexer | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $bodyPath -Encoding utf8NoBOM
    $response = Invoke-SearchCurl -Arguments @(
        '--request'
        'PUT'
        '--header'
        'Content-Type: application/json'
        '--data-binary'
        "@$bodyPath"
        $indexerUri
    )

    if ($response) {
        $updatedIndexer = $response | ConvertFrom-Json
        foreach ($mapping in $mappings) {
            $appliedMapping = @($updatedIndexer.fieldMappings | Where-Object { $_.targetFieldName -eq $mapping.targetFieldName })
            if ($appliedMapping.sourceFieldName -ne $mapping.sourceFieldName) {
                throw "Azure AI Search did not persist the $($mapping.targetFieldName) citation mapping."
            }
        }
    }

    $runUri = "$baseUri/indexers/$IndexerName/run?api-version=2026-08-01-preview"
    $runResult = Invoke-SearchCurl -Arguments @('--request', 'POST', '--data', '', $runUri)
    if ($LASTEXITCODE -ne 0) {
        throw "Azure AI Search could not start indexer $IndexerName."
    }
    Write-Output "Updated $IndexerName with SharePoint citation mappings and started an indexer run."
}
finally {
    if (Test-Path -LiteralPath $bodyPath) {
        Remove-Item -LiteralPath $bodyPath -Force
    }
}
