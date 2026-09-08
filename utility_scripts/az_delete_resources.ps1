#requires -Version 5.1
<#
.SYNOPSIS
Deletes the Metals resource group and all resources inside it.
.DESCRIPTION
Requires Azure CLI and an authenticated session (az login). Waits for deletion
to finish so az_create_resources.ps1 can be run afterward. Database data in
the group is deleted too. Use -WhatIf to preview the target without deleting.
.EXAMPLE
.\utility_scripts\az_delete_resources.ps1 -WhatIf
.EXAMPLE
.\utility_scripts\az_delete_resources.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$UserName = 'dzierzon',
    [string]$Subscription
)

$ErrorActionPreference = 'Stop'
$null = Get-Command az -ErrorAction Stop

function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed with exit code $LASTEXITCODE."
    }
}

$resourceGroup = "expeditors-${UserName}-metals-rg"
$subscriptionArguments = @()
if ($Subscription) {
    $subscriptionArguments = @('--subscription', $Subscription)
}
# Resolve and pin the subscription for every subsequent command.
$subscriptionId = Invoke-Az account show @subscriptionArguments --query id --output tsv
if (-not $subscriptionId) {
    throw 'No Azure subscription was found. Run az login and select your subscription.'
}
$subscriptionId = ([string]$subscriptionId).Trim()
$exists = Invoke-Az group exists --name $resourceGroup --subscription $subscriptionId --output tsv
if (([string]$exists).Trim() -eq 'false') {
    Write-Host "Resource group '$resourceGroup' does not exist in subscription '$subscriptionId'. Nothing to delete."
    return
}
if (([string]$exists).Trim() -ne 'true') {
    throw "Could not determine whether resource group '$resourceGroup' exists."
}

if ($PSCmdlet.ShouldProcess("$resourceGroup (subscription $subscriptionId)", 'Delete resource group and ALL contained resources, including database data')) {
    Write-Host "Deleting '$resourceGroup' and all contained resources. This may take several minutes..."
    Invoke-Az group delete --name $resourceGroup --subscription $subscriptionId --yes
    Write-Host "Deleted '$resourceGroup'. You can now run az_create_resources.ps1 to start over."
}
