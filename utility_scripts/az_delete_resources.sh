#!/usr/bin/env bash
# Requires Azure CLI and an authenticated session (az login).
# Deletes the resource group, including database data, and waits for completion.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_delete_resources.sh [options]

Options:
  --user-name NAME    Resource name suffix (default: dzierzon).
  --subscription ID  Azure subscription name or ID (default: active subscription).
  --what-if          Preview the target without deleting anything.
  -h, --help         Show this help.

Deletes the Metals resource group and ALL contained resources, including
database data. Waits until deletion completes before returning.
EOF
}

user_name='dzierzon'
subscription=''
what_if=false
while (( $# > 0 )); do
    case "$1" in
        --user-name|--subscription)
            if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
                printf 'Missing value for %s.\n' "$1" >&2
                exit 2
            fi
            if [[ "$1" == --user-name ]]; then
                user_name="$2"
            else
                subscription="$2"
            fi
            shift 2
            ;;
        --what-if)
            what_if=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! command -v az >/dev/null 2>&1; then
    printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2
    exit 1
fi

resource_group="expeditors-${user_name}-metals-rg"
subscription_arguments=()
if [[ -n "$subscription" ]]; then
    subscription_arguments=(--subscription "$subscription")
fi

# Resolve and pin the subscription for every subsequent command.
subscription_id=$(az account show "${subscription_arguments[@]}" --query id --output tsv)
# Windows Azure CLI may return CRLF when called from Git Bash.
subscription_id=${subscription_id//$'\r'/}
if [[ -z "$subscription_id" ]]; then
    printf 'No Azure subscription was found. Run az login and select your subscription.\n' >&2
    exit 1
fi

exists=$(az group exists --name "$resource_group" --subscription "$subscription_id" --output tsv)
exists=${exists//$'\r'/}
case "$exists" in
    false)
        printf "Resource group '%s' does not exist in subscription '%s'. Nothing to delete.\n" "$resource_group" "$subscription_id"
        exit 0
        ;;
    true) ;;
    *)
        printf "Could not determine whether resource group '%s' exists.\n" "$resource_group" >&2
        exit 1
        ;;
esac

if [[ "$what_if" == true ]]; then
    printf "What if: Delete resource group '%s' (subscription '%s') and ALL contained resources, including database data.\n" "$resource_group" "$subscription_id"
    exit 0
fi

printf "Deleting '%s' and all contained resources. This may take several minutes...\n" "$resource_group"
az group delete --name "$resource_group" --subscription "$subscription_id" --yes
printf "Deleted '%s'. You can now run az_create_resources.sh to start over.\n" "$resource_group"
