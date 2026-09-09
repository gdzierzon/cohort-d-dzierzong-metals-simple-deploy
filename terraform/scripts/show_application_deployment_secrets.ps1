[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"

$terraformDirectory = (Resolve-Path -LiteralPath $TerraformDirectory).Path

try {
    $secretsJson = & terraform "-chdir=$terraformDirectory" output -json github_secrets
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform output failed with exit code $LASTEXITCODE. Initialize the Terraform remote backend first."
    }

    $secrets = $secretsJson | ConvertFrom-Json
}
catch {
    throw "Could not read the application deployment identity from Terraform state. $($_.Exception.Message)"
}

Write-Host "Add these environment secrets in GitHub:" -ForegroundColor Cyan
Write-Host "Repository > Settings > Environments > Development > Environment secrets" -ForegroundColor DarkCyan
Write-Host ""

foreach ($name in "AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID") {
    $value = $secrets.$name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Terraform output did not contain $name."
    }

    Write-Host "$name = $value"
}

Write-Host ""
Write-Host "These values belong only in the Development environment. Do not replace the TF_AZURE_* secrets in the Terraform environment." -ForegroundColor Yellow
