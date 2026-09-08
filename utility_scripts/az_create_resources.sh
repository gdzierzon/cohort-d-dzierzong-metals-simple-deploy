#!/usr/bin/env bash

userName="dzierzon"

# db:
# expeditors-dzierzon-db
# metalsadmin:P@ssw0rd

#################
# resource group
#################

az group create \
  --name "expeditors-${userName}-metals-rg" \
  --location westus2

#################
# Database
#################

# Standard_B1ms (Burstable) is the smallest/cheapest SKU available for
# PostgreSQL Flexible Server; 32GB storage and 7-day backup retention are
# the platform minimums, and HA / geo-redundancy are disabled since both
# add cost and aren't needed for a dev server.
az postgres flexible-server create \
  --resource-group "expeditors-${userName}-metals-rg" \
  --name "expeditors-${userName}-metals-pg" \
  --location westus2 \
  --admin-user metalsadmin \
  --admin-password 'P@ssw0rd' \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --storage-size 32 \
  --storage-auto-grow Disabled \
  --backup-retention 7 \
  --geo-redundant-backup Disabled \
  --version 16 \
  --public-access 0.0.0.0 \
  --tags Environment=Development


az postgres flexible-server db create \
  --resource-group "expeditors-${userName}-metals-rg" \
  --server-name "expeditors-${userName}-metals-pg" \
  --name metals

######################
# Initialize Database
######################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PGPASSWORD='P@ssw0rd'
export PGSSLMODE='require'

psql \
  --host="expeditors-${userName}-metals-pg.postgres.database.azure.com" \
  --port=5432 \
  --username=metalsadmin \
  --dbname=metals \
  --file="$SCRIPT_DIR/../sql/metals-db.sql"

unset PGPASSWORD
unset PGSSLMODE

########################
# create the app service
########################

az appservice plan create \
  --name "expeditors-${userName}-metals-appservice-plan" \
  --resource-group "expeditors-${userName}-metals-rg" \
  --sku B1 \
  --is-linux \
  --location westus2


az webapp create \
  --name "expeditors-${userName}-metals-api" \
  --resource-group "expeditors-${userName}-metals-rg" \
  --plan "expeditors-${userName}-metals-appservice-plan" \
  --runtime "PYTHON:3.11"

az webapp config set \
  --resource-group "expeditors-${userName}-metals-rg" \
  --name "expeditors-${userName}-metals-api" \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app"

az webapp config appsettings set \
  --resource-group "expeditors-${userName}-metals-rg" \
  --name "expeditors-${userName}-metals-api" \
  --settings DB_HOST="expeditors-${userName}-metals-pg.postgres.database.azure.com" \
             DB_NAME="metals" \
             DB_USER="metalsadmin" \
             DB_PASSWORD="P@ssw0rd" \
             SCM_DO_BUILD_DURING_DEPLOYMENT=true

###################

appName="expeditors-${userName}-metals-api"
dbServer="expeditors-${userName}-metals-pg"
dbUser='metalsadmin'

read -r -p "Enter the PostgreSQL username [$dbUser]: " dbUserInput
dbUser="${dbUserInput:-$dbUser}"

read -r -s -p 'Enter the PostgreSQL password: ' dbPassword
echo

encodedPassword=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$dbPassword")

dbUrl="postgresql://${dbUser}:${encodedPassword}@${dbServer}.postgres.database.azure.com:5432/metals?sslmode=require"

az webapp config appsettings set \
  --resource-group "expeditors-${userName}-metals-rg" \
  --name "$appName" \
  --settings "DB_URL=$dbUrl" "FLASK_DEBUG=0" \
  --output none

unset appName dbServer dbUser dbUserInput dbPassword encodedPassword dbUrl

#####################################
# when not in use, stop the database
#####################################

# az postgres flexible-server stop \
#   --resource-group "expeditors-${userName}-metals-rg" \
#   --name "expeditors-${userName}-metals-pg"
