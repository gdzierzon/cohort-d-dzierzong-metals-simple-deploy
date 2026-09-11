#requires -Version 5.1
<#
.SYNOPSIS
Builds the API and UI container images in Azure Container Registry and
deploys them to their Web Apps.
.DESCRIPTION
Requires Azure CLI (az login) and the resources created by
az_create_resources.ps1. Builds all three images with `az acr build` (no local
Docker required), points each Web App at the new tag, then restarts it so
the container actually re-pulls the image. Does not touch the database.
.EXAMPLE
.\utility_scripts\az_deploy.ps1 -UserName dzierzon
.EXAMPLE
.\utility_scripts\az_deploy.ps1 -UserName dzierzon -ImageTag v2 -FollowLogs
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,24}$')]
    [string]$UserName = 'dzierzon',
    [ValidatePattern('^[a-zA-Z0-9]{5,50}$')]
    [string]$RegistryName,
    [ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$')]
    [string]$ImageTag = 'latest',
    # Skip building/pushing and only repoint + restart the Web Apps at an
    # already-pushed tag.
    [switch]$SkipBuild,
    # Stream each Web App's container logs after restarting it.
    [switch]$FollowLogs
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed with exit code $LASTEXITCODE."
    }
}

$null = Get-Command az -ErrorAction Stop
$projectRoot = Split-Path -Parent $PSScriptRoot
$resourceGroup = "expeditors-${UserName}-metals-rg"
$appName = "expeditors-${UserName}-metals-api"
$uiAppName = "expeditors-${UserName}-metals-ui"
$tutorialsAppName = "expeditors-${UserName}-metals-tutorials"
if (-not $RegistryName) {
    $RegistryName = "expeditors$($UserName.Replace('-', ''))metalsacr"
}

# Confirm an authenticated account, and that provisioning has already run.
$null = Invoke-Az account show --query id --output tsv
$registry = Invoke-Az acr show --name $RegistryName --resource-group $resourceGroup --output json | ConvertFrom-Json

$apps = @(
    @{ Name = $appName; Image = 'metals-api'; Context = $projectRoot; DockerfilePath = 'metals_api/Dockerfile' },
    @{ Name = $uiAppName; Image = 'metals-ui'; Context = (Join-Path $projectRoot 'metals_ui'); DockerfilePath = 'Dockerfile' },
    @{ Name = $tutorialsAppName; Image = 'metals-tutorials'; Context = (Join-Path $projectRoot 'tutorials'); DockerfilePath = 'Dockerfile' }
)

if (-not $SkipBuild) {
    foreach ($webApp in $apps) {
        Write-Host "Building $($webApp.Image):$ImageTag in Azure Container Registry..."
        # az acr build checks --file against the current directory, not
        # SOURCE_LOCATION, so run from each app's own build context.
        Push-Location $webApp.Context
        try {
            Invoke-Az acr build --registry $RegistryName --resource-group $resourceGroup `
                --image "$($webApp.Image):$ImageTag" --file $webApp.DockerfilePath .
        }
        finally { Pop-Location }
    }
}
else {
    Write-Host "Skipping build; repointing Web Apps at the existing $($ImageTag) tag."
}

foreach ($webApp in $apps) {
    $name = $webApp.Name
    $image = "$($registry.loginServer)/$($webApp.Image):$ImageTag"

    # Idempotent: also converts a source-code Web App to a container Web App.
    Invoke-Az webapp config container set --name $name --resource-group $resourceGroup `
        --container-image-name $image `
        --container-registry-url "https://$($registry.loginServer)" --output none

    # config set alone does not force a re-pull when the tag is unchanged
    # (e.g. repeated ":latest" deploys), so always restart explicitly.
    Write-Host "Restarting $name to pull $image..."
    Invoke-Az webapp restart --name $name --resource-group $resourceGroup --output none
}

Write-Host 'Waiting for every Web App to report healthy...'
foreach ($webApp in $apps) {
    $name = $webApp.Name
    $hostName = Invoke-Az webapp show --name $name --resource-group $resourceGroup --query defaultHostName --output tsv
    $healthy = $false
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "https://$hostName/health" -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) { $healthy = $true; break }
        }
        catch { Start-Sleep -Seconds 10 }
    }
    if ($healthy) {
        Write-Host "$name is healthy: https://$hostName/health"
    }
    else {
        Write-Warning "$name did not report healthy at https://$hostName/health within the timeout. Check its logs."
    }
}

if ($FollowLogs) {
    Write-Host "Streaming logs for $appName. Press Ctrl+C to stop; use the commands below to follow the other apps."
    Invoke-Az webapp log config --name $appName --resource-group $resourceGroup --docker-container-logging filesystem --output none
    Invoke-Az webapp log tail --name $appName --resource-group $resourceGroup
}
else {
    Write-Host "To stream logs: az webapp log tail --resource-group $resourceGroup --name $appName"
    Write-Host "           or: az webapp log tail --resource-group $resourceGroup --name $uiAppName"
    Write-Host "           or: az webapp log tail --resource-group $resourceGroup --name $tutorialsAppName"
}
