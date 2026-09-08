#requires -Version 5.1
# Run after az_create_resources.ps1. Requires az login and permission to
# create managed identities and assign roles on the App Service.
# Creates GitHub OIDC trust without a client secret or publish profile.
[CmdletBinding()]
param(
    [string]$UserName = 'dzierzon',
    [string]$Repository = 'gdzierzon/cohort-d-dzierzong-metals-simple-deploy',
    [string]$GitHubEnvironment = 'Development'
)

$ErrorActionPreference = 'Stop'
$null = Get-Command az -ErrorAction Stop
function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed with exit code $LASTEXITCODE."
    }
}

$account = Invoke-Az account show --output json | ConvertFrom-Json
$subscriptionId = $account.id
$resourceGroup = "expeditors-${UserName}-metals-rg"
$appName = "expeditors-${UserName}-metals-api"
$identityName = "expeditors-${UserName}-metals-github"
$app = Invoke-Az webapp show --resource-group $resourceGroup --name $appName `
    --subscription $subscriptionId --query '{id:id,location:location}' --output json | ConvertFrom-Json

$identity = Invoke-Az identity create --resource-group $resourceGroup --name $identityName `
    --location $app.location --subscription $subscriptionId --output json | ConvertFrom-Json

Invoke-Az identity federated-credential create `
    --resource-group $resourceGroup `
    --identity-name $identityName `
    --name github-development `
    --issuer 'https://token.actions.githubusercontent.com' `
    --subject "repo:${Repository}:environment:${GitHubEnvironment}" `
    --audiences 'api://AzureADTokenExchange' `
    --subscription $subscriptionId `
    --output none

Invoke-Az role assignment create `
    --assignee-object-id $identity.principalId `
    --assignee-principal-type ServicePrincipal `
    --role 'Website Contributor' `
    --scope $app.id `
    --subscription $subscriptionId `
    --output none

Write-Host "Add these repository secrets in GitHub: $Repository > Settings > Secrets and variables > Actions"
Write-Host "AZURE_CLIENT_ID = $($identity.clientId)"
Write-Host "AZURE_TENANT_ID = $($identity.tenantId)"
Write-Host "AZURE_SUBSCRIPTION_ID = $subscriptionId"
Write-Host "The workflow must use the GitHub environment '$GitHubEnvironment'."
Write-Host 'Allow a few minutes for the Azure role assignment to propagate before running deployment.'
