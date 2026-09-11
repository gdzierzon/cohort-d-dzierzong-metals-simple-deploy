#!/usr/bin/env bash
# Creates PostgreSQL, a container registry, and the API, UI, and tutorials
# container Web Apps.
# Requires Azure CLI (az login), permission to assign AcrPull roles, and psql
# or Python with psycopg. Creates infrastructure only; images must subsequently
# be built and pushed as metals-api, metals-ui, and metals-tutorials, each
# tagged <image-tag> (see az_deploy.sh). Existing database tables are
# preserved. Use --skip-provisioning to resume after the resource group,
# database server, and database have already been created.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_create_resources.sh [options]

Options:
  --user-name NAME          Resource-name suffix (default: dzierzon).
  --location LOCATION       Azure region (default: westus2).
  --registry-name NAME      Override the generated registry name.
  --image-tag TAG           Expected tag for every image (default: latest).
  --database-password PASS  PostgreSQL admin password. Prompted if omitted.
                             Use the EXISTING password when resuming.
  --psql-path PATH          Full path to a psql executable.
  --client-ip IP            Explicit public IPv4 address, e.g. if a VPN/proxy
                             uses a different database egress IP.
  --skip-provisioning       Resume after the resource group, PostgreSQL
                             server, and database already exist.
  -h, --help                Show this help.
EOF
}

user_name='dzierzon'
location='westus2'
registry_name=''
image_tag='latest'
database_password=''
psql_path=''
client_ip=''
skip_provisioning=false
while (( $# > 0 )); do
    case "$1" in
        --user-name|--location|--registry-name|--image-tag|--database-password|--psql-path|--client-ip)
            (( $# >= 2 )) || { printf 'Missing value for %s.\n' "$1" >&2; exit 2; }
            case "$1" in
                --user-name) user_name="$2" ;;
                --location) location="$2" ;;
                --registry-name) registry_name="$2" ;;
                --image-tag) image_tag="$2" ;;
                --database-password) database_password="$2" ;;
                --psql-path) psql_path="$2" ;;
                --client-ip) client_ip="$2" ;;
            esac
            shift 2
            ;;
        --skip-provisioning) skip_provisioning=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ "$user_name" =~ ^[a-z0-9][a-z0-9-]{0,24}$ ]] || { printf -- '--user-name must be lowercase letters, digits, or hyphens (max 25 chars).\n' >&2; exit 2; }
if [[ -n "$registry_name" ]]; then
    [[ "$registry_name" =~ ^[a-zA-Z0-9]{5,50}$ ]] || { printf -- '--registry-name must be 5-50 letters or digits.\n' >&2; exit 2; }
fi
[[ "$image_tag" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || { printf -- '--image-tag is not a valid image tag.\n' >&2; exit 2; }

command -v az >/dev/null 2>&1 || { printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf 'curl was not found; it is required to detect the local public IPv4 address.\n' >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { printf 'openssl was not found; it is required to generate the JWT signing key.\n' >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

# Locate psql, falling back to Python with psycopg.
python_command=''
if [[ -z "$psql_path" ]]; then
    if command -v psql >/dev/null 2>&1; then
        psql_path="$(command -v psql)"
    fi
fi
if [[ -z "$psql_path" ]]; then
    for candidate in "$project_root/.venv/bin/python" "$project_root/.venv/Scripts/python.exe" python3 python; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        if "$candidate" -c 'import psycopg' >/dev/null 2>&1; then
            python_command="$candidate"
            break
        fi
    done
    if [[ -z "$python_command" ]]; then
        printf 'Database initialization requires psql or Python with psycopg. Run: python -m pip install "psycopg[binary]>=3.0,<4.0", or pass --psql-path with the full path to psql.\n' >&2
        exit 1
    fi
    printf 'psql was not found; using Python with psycopg to initialize the database.\n'
fi

resource_group="expeditors-${user_name}-metals-rg"
db_server="expeditors-${user_name}-metals-pg"
app_name="expeditors-${user_name}-metals-api"
plan_name="expeditors-${user_name}-metals-appservice-plan"
ui_app_name="expeditors-${user_name}-metals-ui"
tutorials_app_name="expeditors-${user_name}-metals-tutorials"
if [[ -z "$registry_name" ]]; then
    registry_name="expeditors${user_name//-/}metalsacr"
fi

# Confirm an authenticated account before starting provisioning.
az account show --query id --output tsv >/dev/null

if [[ -z "$database_password" ]]; then
    read -r -s -p 'PostgreSQL administrator password (use the existing password when resuming): ' database_password
    echo
fi
[[ -n "$database_password" ]] || { printf 'A database password is required.\n' >&2; exit 1; }

# Resolve the local client's public IPv4 address before provisioning resources.
if [[ -z "$client_ip" ]]; then
    client_ip="$(curl -s --max-time 15 https://api4.ipify.org || true)"
    client_ip=${client_ip//$'\r'/}
    [[ -n "$client_ip" ]] || { printf 'Could not detect your public IPv4 address. Rerun with --client-ip <your-public-IPv4-address>.\n' >&2; exit 1; }
fi
if ! [[ "$client_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ "$client_ip" == '0.0.0.0' ]]; then
    printf -- '--client-ip must be a nonzero IPv4 address for this computer.\n' >&2
    exit 1
fi

if [[ "$skip_provisioning" == false ]]; then
    az group create --name "$resource_group" --location "$location" --output none

    # Database: preserve the development settings used previously.
    az postgres flexible-server create \
        --resource-group "$resource_group" \
        --name "$db_server" \
        --location "$location" \
        --admin-user metalsadmin \
        --admin-password "$database_password" \
        --tier Burstable \
        --sku-name Standard_B1ms \
        --storage-size 32 \
        --storage-auto-grow Disabled \
        --backup-retention 7 \
        --geo-redundant-backup Disabled \
        --version 16 \
        --public-access 0.0.0.0 \
        --tags Environment=Development --output none

    az postgres flexible-server db create \
        --resource-group "$resource_group" \
        --server-name "$db_server" \
        --name metals --output none
else
    printf 'Using existing resource group, PostgreSQL server, and database. Resuming at firewall configuration.\n'
fi

# The 0.0.0.0 rule above allows Azure services, not this local computer.
az postgres flexible-server firewall-rule create \
    --resource-group "$resource_group" \
    --server-name "$db_server" \
    --name "LocalClient-${client_ip//./-}" \
    --start-ip-address "$client_ip" \
    --end-ip-address "$client_ip" \
    --output none

# Initialize the database, then restore the caller's environment.
sql_path="$project_root/sql/metals-db.sql"
export PGPASSWORD="$database_password"
export PGSSLMODE='require'
export PGCONNECT_TIMEOUT='15'
init_failed=false
if [[ -n "$psql_path" ]]; then
    existing_tables=$("$psql_path" \
        --host="${db_server}.postgres.database.azure.com" --port=5432 \
        --username=metalsadmin --dbname=metals --set=ON_ERROR_STOP=1 \
        --tuples-only --no-align \
        --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';") || init_failed=true
    existing_tables=$(printf '%s' "$existing_tables" | tr -d '[:space:]')
    if [[ "$init_failed" == false ]]; then
        if [[ "${existing_tables:-0}" -gt 0 ]]; then
            printf 'Existing database tables found; preserving schema and data.\n'
        else
            "$psql_path" \
                --host="${db_server}.postgres.database.azure.com" \
                --port=5432 \
                --username=metalsadmin \
                --dbname=metals \
                --set=ON_ERROR_STOP=1 \
                --single-transaction \
                --file="$sql_path" || init_failed=true
        fi
    fi
else
    "$python_command" - "${db_server}.postgres.database.azure.com" "$sql_path" <<'PYEOF' || init_failed=true
import pathlib
import sys
import psycopg

sql = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8-sig")
with psycopg.connect(host=sys.argv[1], port=5432, user="metalsadmin", dbname="metals") as connection:
    count = connection.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'").fetchone()[0]
    if count:
        print("Existing database tables found; preserving schema and data.")
    else:
        connection.execute(sql)
PYEOF
fi
unset PGPASSWORD PGSSLMODE PGCONNECT_TIMEOUT
if [[ "$init_failed" == true ]]; then
    printf 'Database initialization failed. If the connection timed out, allow up to five minutes for the firewall rule to propagate and verify your network permits outbound TCP 5432. If using a VPN/proxy, supply --client-ip with the database connection'"'"'s public egress IPv4 address.\n' >&2
    exit 1
fi

# Registry permissions use AcrPull with classic registry RBAC, not ABAC.
az acr create --name "$registry_name" --resource-group "$resource_group" \
    --location "$location" --sku Basic --admin-enabled false \
    --role-assignment-mode rbac --output none
registry_login_server=$(az acr show --name "$registry_name" --resource-group "$resource_group" --query loginServer --output tsv)
registry_login_server=${registry_login_server//$'\r'/}
registry_id=$(az acr show --name "$registry_name" --resource-group "$resource_group" --query id --output tsv)
registry_id=${registry_id//$'\r'/}

az appservice plan create --name "$plan_name" --resource-group "$resource_group" \
    --sku B1 --is-linux --location "$location" --output none

app_names=("$app_name" "$ui_app_name" "$tutorials_app_name")
app_images=('metals-api' 'metals-ui' 'metals-tutorials')
app_ports=('5000' '8080' '8080')

existing_apps=$(az webapp list --resource-group "$resource_group" --query '[].name' --output tsv)
for i in "${!app_names[@]}"; do
    name="${app_names[$i]}"
    image="${registry_login_server}/${app_images[$i]}:${image_tag}"

    if ! grep -qx "$name" <<<"$existing_apps"; then
        # Images can be pushed later. The app will not serve traffic until then.
        az webapp create --name "$name" --resource-group "$resource_group" \
            --plan "$plan_name" --container-image-name "$image" \
            --assign-identity '[system]' --acr-use-identity --acr-identity '[system]' --output none
    fi
    principal_id=$(az webapp identity assign --name "$name" \
        --resource-group "$resource_group" --query principalId --output tsv)
    principal_id=${principal_id//$'\r'/}
    az role assignment create --assignee-object-id "$principal_id" \
        --assignee-principal-type ServicePrincipal --scope "$registry_id" \
        --role AcrPull --output none

    # Also converts an existing source-code Web App to a container Web App.
    az webapp config container set --name "$name" --resource-group "$resource_group" \
        --container-image-name "$image" \
        --container-registry-url "https://${registry_login_server}" --output none

    az webapp config set --name "$name" --resource-group "$resource_group" \
        --generic-configurations '{"acrUseManagedIdentityCreds": true, "acrUserManagedIdentityID": "", "appCommandLine": "", "alwaysOn": true, "healthCheckPath": "/health"}' \
        --output none

    az webapp update --name "$name" --resource-group "$resource_group" --https-only true --output none
    az webapp config appsettings set --resource-group "$resource_group" --name "$name" \
        --settings "WEBSITES_PORT=${app_ports[$i]}" \
                   'WEBSITES_ENABLE_APP_SERVICE_STORAGE=false' \
                   'SCM_DO_BUILD_DURING_DEPLOYMENT=false' \
        --output none
    az webapp log config --name "$name" --resource-group "$resource_group" \
        --docker-container-logging filesystem --output none
done

# Preserve an existing signing key so a provisioning rerun does not revoke JWTs.
jwt_secret=$(az webapp config appsettings list --name "$app_name" \
    --resource-group "$resource_group" --query "[?name=='JWT_SECRET_KEY'].value | [0]" --output tsv)
jwt_secret=${jwt_secret//$'\r'/}
if [[ -z "$jwt_secret" || "$jwt_secret" == 'None' ]]; then
    jwt_secret=$(openssl rand -base64 48)
fi

az webapp config appsettings set --resource-group "$resource_group" --name "$app_name" \
    --settings "DB_HOST=${db_server}.postgres.database.azure.com" \
               'DB_PORT=5432' \
               'DB_NAME=metals' \
               'DB_USER=metalsadmin' \
               "DB_PASSWORD=${database_password}" \
               'PGSSLMODE=require' \
               "JWT_SECRET_KEY=${jwt_secret}" \
               'JWT_EXPIRATION_MINUTES=60' \
               'FLASK_DEBUG=0' \
    --output none
unset database_password jwt_secret

# Use Azure's actual hostname (which may include a region/unique suffix).
api_host=$(az webapp show --name "$app_name" --resource-group "$resource_group" --query defaultHostName --output tsv)
api_host=${api_host//$'\r'/}
ui_host=$(az webapp show --name "$ui_app_name" --resource-group "$resource_group" --query defaultHostName --output tsv)
ui_host=${ui_host//$'\r'/}
tutorials_host=$(az webapp show --name "$tutorials_app_name" --resource-group "$resource_group" --query defaultHostName --output tsv)
tutorials_host=${tutorials_host//$'\r'/}
az webapp config appsettings set --resource-group "$resource_group" --name "$ui_app_name" \
    --settings "API_UPSTREAM=https://${api_host}" \
               'NGINX_RESOLVER=168.63.129.16' \
    --output none
# The tutorial site is fully static and needs no settings beyond the container
# defaults applied in the loop above.

printf 'Resource group: %s\n' "$resource_group"
printf 'Container registry: %s\n' "$registry_login_server"
printf 'API image: %s/metals-api:%s\n' "$registry_login_server" "$image_tag"
printf 'UI image: %s/metals-ui:%s\n' "$registry_login_server" "$image_tag"
printf 'Tutorials image: %s/metals-tutorials:%s\n' "$registry_login_server" "$image_tag"
printf 'API URL: https://%s\n' "$api_host"
printf 'UI URL: https://%s\n' "$ui_host"
printf 'Tutorials URL: https://%s\n' "$tutorials_host"
printf 'Infrastructure configured. Build and push the images (see az_deploy.sh), then restart the Web Apps.\n'
