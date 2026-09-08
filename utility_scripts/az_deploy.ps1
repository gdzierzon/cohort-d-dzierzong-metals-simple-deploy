#requires -Version 5.1
# Requires Azure CLI on PATH and an authenticated session (az login).
[CmdletBinding()]
param(
    [string]$UserName = 'dzierzon'
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
$appDirectory = Join-Path $projectRoot 'metals_api'
$deployZip = Join-Path $PSScriptRoot 'deploy.zip'
$resourceGroup = "expeditors-${UserName}-metals-rg"
$appName = "expeditors-${UserName}-metals-api"

# Package the application at the archive root with requirements.txt.
# Use forward slashes for ZIP paths consumed by Linux App Service.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Add-AppFiles {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Directory,
        [string]$Prefix = ''
    )

    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        $entryName = $Prefix + $item.Name
        if ($item.PSIsContainer) {
            if ($item.Name -notin @('__pycache__', '.pytest_cache')) {
                Add-AppFiles -Archive $Archive -Directory $item.FullName -Prefix "$entryName/"
            }
        }
        else {
            $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $Archive, $item.FullName, $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
        }
    }
}

if (Test-Path -LiteralPath $deployZip) {
    Remove-Item -LiteralPath $deployZip -Force
}
$archive = [System.IO.Compression.ZipFile]::Open(
    $deployZip, [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    Add-AppFiles -Archive $archive -Directory $appDirectory
    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, (Join-Path $projectRoot 'requirements.txt'), 'requirements.txt',
        [System.IO.Compression.CompressionLevel]::Optimal
    )
}
finally {
    $archive.Dispose()
}

Invoke-Az webapp deploy `
    --name $appName `
    --resource-group $resourceGroup `
    --src-path $deployZip `
    --type zip

# Enable application logging and stream logs until Ctrl+C.
Invoke-Az webapp log config `
    --name $appName `
    --resource-group $resourceGroup `
    --application-logging filesystem `
    --level information

Invoke-Az webapp log tail --name $appName --resource-group $resourceGroup
