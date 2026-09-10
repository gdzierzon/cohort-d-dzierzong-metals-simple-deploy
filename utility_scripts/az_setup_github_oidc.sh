#!/usr/bin/env bash
# Run after az_create_resources.sh. Requires az login and permission to create
# managed identities and assign roles on the App Service.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_setup_github_oidc.sh [options]

Options:
  --user-name NAME            Resource name suffix (default: dzierzon).
  --repository OWNER/REPO     GitHub repository (default: this demo repository).
  --github-environment NAME   GitHub environment (default: Development).
  --federated-subject VALUE   Exact subject from the azure/login action log.
  --update-credential-only    Repair the federated credential without changing identity or roles.
  -h, --help                  Show this help.
EOF
}

user_name='dzierzon'
repository='gdzierzon/cohort-d-dzierzong-metals-simple-deploy'
github_environment='Development'
federated_subject=''
update_credential_only=false
while (( $# > 0 )); do
    case "$1" in
        --user-name|--repository|--github-environment|--federated-subject)
            (( $# >= 2 )) || { printf 'Missing value for %s.\n' "$1" >&2; exit 2; }
            case "$1" in
                --user-name) user_name="$2" ;;
                --repository) repository="$2" ;;
                --github-environment) github_environment="$2" ;;
                --federated-subject) federated_subject="$2" ;;
            esac
            shift 2
            ;;
        --update-credential-only) update_credential_only=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v az >/dev/null 2>&1 || { printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2; exit 1; }
subscription_id=$(az account show --query id --output tsv)
[[ -n "$subscription_id" ]] || { printf 'No Azure subscription was found. Run az login and select your subscription.\n' >&2; exit 1; }

resource_group="expeditors-${user_name}-metals-rg"
app_name="expeditors-${user_name}-metals-api"
identity_name="expeditors-${user_name}-metals-github"
if [[ -z "$federated_subject" ]]; then
    if [[ "$repository" != 'gdzierzon/cohort-d-dzierzong-metals-simple-deploy' ]]; then
        printf 'For another repository, pass --federated-subject with the exact subject claim from the azure/login log.\n' >&2
        exit 1
    fi
    federated_subject="repo:gdzierzon@9723466/cohort-d-dzierzong-metals-simple-deploy@1361521533:environment:${github_environment//:/%3A}"
fi

if [[ "$update_credential_only" == true ]]; then
    az identity federated-credential update \
        --resource-group "$resource_group" --identity-name "$identity_name" --name github-development \
        --issuer 'https://token.actions.githubusercontent.com' --subject "$federated_subject" \
        --audiences 'api://AzureADTokenExchange' --subscription "$subscription_id" --output none
    printf 'Updated federated credential subject: %s\n' "$federated_subject"
    printf 'GitHub secrets stay the same. Allow a few minutes for propagation, then rerun the failed job.\n'
    exit 0
fi

app_id=$(az webapp show --resource-group "$resource_group" --name "$app_name" --subscription "$subscription_id" --query id --output tsv)
app_location=$(az webapp show --resource-group "$resource_group" --name "$app_name" --subscription "$subscription_id" --query location --output tsv)
az identity create --resource-group "$resource_group" --name "$identity_name" --location "$app_location" --subscription "$subscription_id" --output none
principal_id=$(az identity show --resource-group "$resource_group" --name "$identity_name" --subscription "$subscription_id" --query principalId --output tsv)
client_id=$(az identity show --resource-group "$resource_group" --name "$identity_name" --subscription "$subscription_id" --query clientId --output tsv)
tenant_id=$(az identity show --resource-group "$resource_group" --name "$identity_name" --subscription "$subscription_id" --query tenantId --output tsv)

az identity federated-credential create \
    --resource-group "$resource_group" --identity-name "$identity_name" --name github-development \
    --issuer 'https://token.actions.githubusercontent.com' --subject "$federated_subject" \
    --audiences 'api://AzureADTokenExchange' --subscription "$subscription_id" --output none
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
    --role 'Website Contributor' --scope "$app_id" --subscription "$subscription_id" --output none

printf 'Add these environment secrets in GitHub: %s > Settings > Environments > %s > Environment secrets\n' "$repository" "$github_environment"
printf 'AZURE_CLIENT_ID = %s\n' "$client_id"
printf 'AZURE_TENANT_ID = %s\n' "$tenant_id"
printf 'AZURE_SUBSCRIPTION_ID = %s\n' "$subscription_id"
printf "The workflow must use the GitHub environment '%s'.\n" "$github_environment"
printf 'Allow a few minutes for the Azure role assignment to propagate before running deployment.\n'
