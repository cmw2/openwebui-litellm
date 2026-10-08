[CmdletBinding()]
param(
    [ValidateSet('WhatIf', 'Deploy')]
    [string]$Mode = 'WhatIf'
)

$ErrorActionPreference = 'Stop'

function Get-AzdEnvironmentValue {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = (azd env get-value $Name).Trim()
    if (-not $value) {
        throw "The active azd environment is missing $Name."
    }

    return $value
}

function Get-InfrastructureParameter {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = (azd env config get "infra.parameters.$Name").Trim()
    if (-not $value) {
        throw "The active azd environment is missing infra.parameters.$Name."
    }

    return $value
}

$subscriptionId = Get-AzdEnvironmentValue 'AZURE_SUBSCRIPTION_ID'
$location = Get-AzdEnvironmentValue 'AZURE_LOCATION'
$environmentName = Get-AzdEnvironmentValue 'AZURE_ENV_NAME'
$currentSubscriptionId = (az account show --query id --output tsv).Trim()

if ($currentSubscriptionId -ne $subscriptionId) {
    az account set --subscription $subscriptionId
}

$parameterNames = @(
    'apimLocation'
    'litellmMasterKey'
    'openWebUiSecretKey'
    'postgresAdminPassword'
    'apimFoundryAgentSubscriptionKey'
    'apimPublisherEmail'
    'litellmContainerImage'
    'openwebuiContainerImage'
    'vnetAddressPrefix'
    'containerAppsSubnetPrefix'
    'postgresSubnetPrefix'
    'provisionNetwork'
    'searchSkuName'
    'promptAgentName'
    'promptAgentModelAlias'
)

$parameters = @(
    "environmentName=$environmentName"
    "location=$location"
)

foreach ($name in $parameterNames) {
    $parameters += "$name=$(Get-InfrastructureParameter $name)"
}

$deploymentName = "$environmentName-$(Get-Date -Format 'yyyyMMddHHmmss')"
$commonArguments = @(
    'deployment'
    'sub'
    '--name'
    $deploymentName
    '--location'
    $location
    '--template-file'
    'infra/main.bicep'
    '--parameters'
) + $parameters

if ($Mode -eq 'WhatIf') {
    az @($commonArguments[0..1] + 'what-if' + $commonArguments[2..($commonArguments.Count - 1)])
    exit $LASTEXITCODE
}

az @($commonArguments[0..1] + 'validate' + $commonArguments[2..($commonArguments.Count - 1)])
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

az @($commonArguments[0..1] + 'create' + $commonArguments[2..($commonArguments.Count - 1)])
exit $LASTEXITCODE
