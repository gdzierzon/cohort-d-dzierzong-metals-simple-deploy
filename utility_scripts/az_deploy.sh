#!/usr/bin/env bash
# Requires Azure CLI (az login) and zip.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_deploy.sh [--user-name NAME]
EOF
}

user_name='dzierzon'
while (( $# > 0 )); do
    case "$1" in
        --user-name) (( $# >= 2 )) || { printf 'Missing value for --user-name.\n' >&2; exit 2; }; user_name="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v az >/dev/null 2>&1 || { printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { printf 'zip was not found. Install zip and try again.\n' >&2; exit 1; }

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
app_directory="$project_root/metals_api"
deploy_zip=$(mktemp "${TMPDIR:-/tmp}/metals-deploy.XXXXXX.zip")
trap 'rm -f "$deploy_zip"' EXIT
resource_group="expeditors-${user_name}-metals-rg"
app_name="expeditors-${user_name}-metals-api"

(cd "$app_directory" && zip -q -r "$deploy_zip" . -x '__pycache__/*' '.pytest_cache/*')
zip -q -j "$deploy_zip" "$project_root/requirements.txt"

az webapp deploy --name "$app_name" --resource-group "$resource_group" --src-path "$deploy_zip" --type zip
az webapp log config --name "$app_name" --resource-group "$resource_group" --application-logging filesystem --level information
az webapp log tail --name "$app_name" --resource-group "$resource_group"
