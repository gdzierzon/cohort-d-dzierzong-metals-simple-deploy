#!/usr/bin/env bash
# Builds the API and UI container images in Azure Container Registry and
# deploys them to their Web Apps. Requires Azure CLI (az login) and the
# resources created by az_create_resources.sh. Builds both images with
# `az acr build` (no local Docker required), points each Web App at the new
# tag, then restarts it so the container actually re-pulls the image. Does
# not touch the database.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_deploy.sh [options]

Options:
  --user-name NAME      Resource-name suffix (default: dzierzon).
  --registry-name NAME  Override the generated registry name.
  --image-tag TAG       Tag to build and deploy (default: latest).
  --skip-build          Only repoint and restart the Web Apps at an
                         already-pushed tag.
  --follow-logs         Stream the API's container logs after restarting.
  -h, --help            Show this help.
EOF
}

user_name='dzierzon'
registry_name=''
image_tag='latest'
skip_build=false
follow_logs=false
while (( $# > 0 )); do
    case "$1" in
        --user-name|--registry-name|--image-tag)
            (( $# >= 2 )) || { printf 'Missing value for %s.\n' "$1" >&2; exit 2; }
            case "$1" in
                --user-name) user_name="$2" ;;
                --registry-name) registry_name="$2" ;;
                --image-tag) image_tag="$2" ;;
            esac
            shift 2
            ;;
        --skip-build) skip_build=true; shift ;;
        --follow-logs) follow_logs=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v az >/dev/null 2>&1 || { printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf 'curl was not found; it is required for the health check polling.\n' >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
resource_group="expeditors-${user_name}-metals-rg"
app_name="expeditors-${user_name}-metals-api"
ui_app_name="expeditors-${user_name}-metals-ui"
if [[ -z "$registry_name" ]]; then
    registry_name="expeditors${user_name//-/}metalsacr"
fi

# Confirm an authenticated account, and that provisioning has already run.
az account show --query id --output tsv >/dev/null
registry_login_server=$(az acr show --name "$registry_name" --resource-group "$resource_group" --query loginServer --output tsv)
registry_login_server=${registry_login_server//$'\r'/}

app_names=("$app_name" "$ui_app_name")
app_images=('metals-api' 'metals-ui')
app_contexts=("$project_root" "$project_root/metals_ui")
app_dockerfiles=('metals_api/Dockerfile' 'Dockerfile')

if [[ "$skip_build" == false ]]; then
    for i in "${!app_names[@]}"; do
        printf 'Building %s:%s in Azure Container Registry...\n' "${app_images[$i]}" "$image_tag"
        # az acr build checks --file against the current directory, not
        # SOURCE_LOCATION, so run from each app's own build context.
        (cd "${app_contexts[$i]}" && az acr build --registry "$registry_name" --resource-group "$resource_group" \
            --image "${app_images[$i]}:${image_tag}" --file "${app_dockerfiles[$i]}" .)
    done
else
    printf 'Skipping build; repointing Web Apps at the existing %s tag.\n' "$image_tag"
fi

for i in "${!app_names[@]}"; do
    name="${app_names[$i]}"
    image="${registry_login_server}/${app_images[$i]}:${image_tag}"

    # Idempotent: also converts a source-code Web App to a container Web App.
    az webapp config container set --name "$name" --resource-group "$resource_group" \
        --container-image-name "$image" \
        --container-registry-url "https://${registry_login_server}" --output none

    # config set alone does not force a re-pull when the tag is unchanged
    # (e.g. repeated ":latest" deploys), so always restart explicitly.
    printf 'Restarting %s to pull %s...\n' "$name" "$image"
    az webapp restart --name "$name" --resource-group "$resource_group" --output none
done

printf 'Waiting for both Web Apps to report healthy...\n'
for name in "${app_names[@]}"; do
    host_name=$(az webapp show --name "$name" --resource-group "$resource_group" --query defaultHostName --output tsv)
    host_name=${host_name//$'\r'/}
    healthy=false
    for _ in $(seq 1 10); do
        status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${host_name}/health" || true)
        if [[ "$status" == '200' ]]; then
            healthy=true
            break
        fi
        sleep 10
    done
    if [[ "$healthy" == true ]]; then
        printf '%s is healthy: https://%s/health\n' "$name" "$host_name"
    else
        printf 'Warning: %s did not report healthy at https://%s/health within the timeout. Check its logs.\n' "$name" "$host_name" >&2
    fi
done

if [[ "$follow_logs" == true ]]; then
    printf 'Streaming logs for %s. Press Ctrl+C to stop, then rerun with --user-name %s to follow %s separately.\n' "$app_name" "$user_name" "$ui_app_name"
    az webapp log config --name "$app_name" --resource-group "$resource_group" --docker-container-logging filesystem --output none
    az webapp log tail --name "$app_name" --resource-group "$resource_group"
else
    printf 'To stream logs: az webapp log tail --resource-group %s --name %s\n' "$resource_group" "$app_name"
    printf '           or: az webapp log tail --resource-group %s --name %s\n' "$resource_group" "$ui_app_name"
fi
