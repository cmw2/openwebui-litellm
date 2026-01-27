<#
.SYNOPSIS
    Grants an application read access to a SharePoint site.

.DESCRIPTION
    This script grants an application specified permissions to a SharePoint site
    using Microsoft Graph API with Sites.Selected permissions.

.PARAMETER SharePointDomain
    Your SharePoint domain (e.g., "contoso.sharepoint.com")

.PARAMETER SitePath
    Path to the SharePoint site (e.g., "/sites/Finance")

.PARAMETER AppClientId
    Application (client) ID of the app to grant access

.PARAMETER AppDisplayName
    Display name of the application

.PARAMETER Roles
    Roles to grant. Valid values: "read", "write", "owner". Defaults to "read".

.EXAMPLE
    .\set-sp-site-selected.ps1 -SharePointDomain "contoso.sharepoint.com" -SitePath "/sites/Finance" -AppClientId "12345678-1234-1234-1234-123456789012" -AppDisplayName "My App"

.EXAMPLE
    .\set-sp-site-selected.ps1 -SharePointDomain "contoso.sharepoint.com" -SitePath "/sites/Finance" -AppClientId "12345678-1234-1234-1234-123456789012" -AppDisplayName "My App" -Roles @("write")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Your SharePoint domain (e.g., 'contoso.sharepoint.com')")]
    [string]$SharePointDomain,

    [Parameter(Mandatory = $true, HelpMessage = "Path to the SharePoint site (e.g., '/sites/Finance')")]
    [string]$SitePath,

    [Parameter(Mandatory = $true, HelpMessage = "Application (client) ID of the app to grant access")]
    [string]$AppClientId,

    [Parameter(Mandatory = $true, HelpMessage = "Display name of the application")]
    [string]$AppDisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "Roles to grant (e.g., 'read', 'write', 'owner')")]
    [ValidateSet("read", "write", "owner")]
    [string[]]$Roles = @("read")
)

# ============================================
# Script Logic
# ============================================

# Ensure SitePath starts with /
if (-not $SitePath.StartsWith("/")) {
    $SitePath = "/$SitePath"
}

Connect-MgGraph -Scopes "Sites.FullControl.All"

# get site by path
$siteUri = "https://graph.microsoft.com/v1.0/sites/$($SharePointDomain):$($SitePath)"
Write-Verbose "Getting site from: $siteUri"

$site = Invoke-MgGraphRequest `
  -Method GET `
  -Uri $siteUri

# grant app access
# Note: grantedToIdentities is used for the request body (grantedToIdentitiesV2 is returned in the response)
$body = @{
  roles = $Roles
  grantedToIdentities = @(@{
    application = @{
      id = $AppClientId
      displayName = $AppDisplayName
    }
  })
}

Invoke-MgGraphRequest `
  -Method POST `
  -Uri "https://graph.microsoft.com/v1.0/sites/$($site.id)/permissions" `
  -Body ($body | ConvertTo-Json -Depth 5)
