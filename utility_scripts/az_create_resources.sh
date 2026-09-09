#!/usr/bin/env bash
# Requires Azure CLI (az login), plus psql or Python with psycopg installed.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash utility_scripts/az_create_resources.sh [options]

Options:
  --user-name NAME  Resource name suffix (default: dzierzon).
  --psql-path PATH  Full path to psql. If omitted, use psql on PATH or Python/psycopg.
  --client-ip IP    Public IPv4 address allowed to initialize PostgreSQL.
  -h, --help        Show this help.
EOF
}

user_name='dzierzon'
psql_path=''
client_ip=''
while (( $# > 0 )); do
    case "$1" in
        --user-name|--psql-path|--client-ip)
            (( $# >= 2 )) || { printf 'Missing value for %s.\n' "$1" >&2; exit 2; }
            case "$1" in
                --user-name) user_name="$2" ;;
                --psql-path) psql_path="$2" ;;
                --client-ip) client_ip="$2" ;;
            esac
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v az >/dev/null 2>&1 || { printf 'Azure CLI (az) was not found. Install it and run az login.\n' >&2; exit 1; }

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n "$psql_path" ]]; then
    [[ -x "$psql_path" ]] || { printf 'psql was not executable: %s\n' "$psql_path" >&2; exit 1; }
elif command -v psql >/dev/null 2>&1; then
    psql_path=$(command -v psql)
fi

python_path=''
if [[ -z "$psql_path" ]]; then
    for candidate in "$project_root/.venv/bin/python" "$project_root/.venv/Scripts/python.exe" python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import psycopg' >/dev/null 2>&1; then
            python_path=$(command -v "$candidate")
            break
        fi
    done
    [[ -n "$python_path" ]] || { printf 'Database initialization requires psql or Python with psycopg. Run: python -m pip install "psycopg[binary]>=3.0,<4.0".\n' >&2; exit 1; }
    printf 'psql was not found; using Python with psycopg to initialize the database.\n'
fi

urlencode_python="$python_path"
if [[ -z "$urlencode_python" ]]; then
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            urlencode_python=$(command -v "$candidate")
            break
        fi
    done
fi
[[ -n "$urlencode_python" ]] || { printf 'Python is required to encode the database password for DB_URL.\n' >&2; exit 1; }

if [[ -z "$client_ip" ]]; then
    client_ip=$(curl --fail --silent --show-error --max-time 15 https://api4.ipify.org) || {
        printf 'Could not detect your public IPv4 address. Rerun with --client-ip <your-public-IPv4-address>.\n' >&2; exit 1;
    }
fi
if [[ ! "$client_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$client_ip" == '0.0.0.0' ]]; then
    printf '%s\n' '--client-ip must be a nonzero IPv4 address for this computer.' >&2
    exit 1
fi

resource_group="expeditors-${user_name}-metals-rg"
db_server="expeditors-${user_name}-metals-pg"
app_name="expeditors-${user_name}-metals-api"
plan_name="expeditors-${user_name}-metals-appservice-plan"
sql_path="$project_root/sql/metals-db.sql"

az group create --name "$resource_group" --location westus2
az postgres flexible-server create \
    --resource-group "$resource_group" --name "$db_server" --location westus2 \
    --admin-user metalsadmin --admin-password 'P@ssw0rd' --tier Burstable \
    --sku-name Standard_B1ms --storage-size 32 --storage-auto-grow Disabled \
    --backup-retention 7 --geo-redundant-backup Disabled --version 16 \
    --public-access 0.0.0.0 --tags Environment=Development
az postgres flexible-server db create --resource-group "$resource_group" --server-name "$db_server" --name metals
az postgres flexible-server firewall-rule create \
    --resource-group "$resource_group" --server-name "$db_server" \
    --name "LocalClient-${client_ip//./-}" --start-ip-address "$client_ip" --end-ip-address "$client_ip" --output none

export PGPASSWORD='P@ssw0rd' PGSSLMODE=require PGCONNECT_TIMEOUT=15
if [[ -n "$psql_path" ]]; then
    "$psql_path" --host="$db_server.postgres.database.azure.com" --port=5432 \
        --username=metalsadmin --dbname=metals --set=ON_ERROR_STOP=1 --file="$sql_path"
else
    "$python_path" - "$db_server.postgres.database.azure.com" "$sql_path" <<'PY'
import pathlib
import sys
import psycopg

sql = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8-sig")
with psycopg.connect(host=sys.argv[1], port=5432, user="metalsadmin", dbname="metals") as connection:
    connection.execute(sql)
PY
fi
unset PGPASSWORD PGSSLMODE PGCONNECT_TIMEOUT

az appservice plan create --name "$plan_name" --resource-group "$resource_group" --sku B1 --is-linux --location westus2
az webapp create --name "$app_name" --resource-group "$resource_group" --plan "$plan_name" --runtime 'PYTHON:3.11'
az webapp config set --resource-group "$resource_group" --name "$app_name" --startup-file 'gunicorn --bind=0.0.0.0 --timeout 600 app:app'
az webapp config appsettings set --resource-group "$resource_group" --name "$app_name" \
    --settings "DB_HOST=$db_server.postgres.database.azure.com" DB_NAME=metals DB_USER=metalsadmin \
    DB_PASSWORD='P@ssw0rd' SCM_DO_BUILD_DURING_DEPLOYMENT=true

db_user='metalsadmin'
read -r -p "Enter the PostgreSQL username [$db_user]: " db_user_input
[[ -z "$db_user_input" ]] || db_user="$db_user_input"
read -r -s -p 'Enter the PostgreSQL password: ' db_password
printf '\n'
encoded_password=$("$urlencode_python" -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))' <<<"$db_password")
unset db_password
db_url="postgresql://${db_user}:${encoded_password}@${db_server}.postgres.database.azure.com:5432/metals?sslmode=require"
unset encoded_password
az webapp config appsettings set --resource-group "$resource_group" --name "$app_name" --settings "DB_URL=$db_url" FLASK_DEBUG=0 --output none
unset db_url

az postgres flexible-server stop --resource-group "$resource_group" --name "$db_server"
