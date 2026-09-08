#!/usr/bin/env bash

userName="dzierzon"

###################
# Compress / Zip
###################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPLOY_ZIP="$SCRIPT_DIR/deploy.zip"

rm -f "$DEPLOY_ZIP"
python3 - "$PROJECT_ROOT" "$DEPLOY_ZIP" <<'PYEOF'
import os
import sys
import zipfile

project_root, deploy_zip = sys.argv[1], sys.argv[2]
app_dir = os.path.join(project_root, "metals_api")

with zipfile.ZipFile(deploy_zip, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(app_dir):
        dirs[:] = [d for d in dirs if d not in ("__pycache__", ".pytest_cache")]
        for name in files:
            full_path = os.path.join(root, name)
            zf.write(full_path, os.path.relpath(full_path, app_dir))
    zf.write(os.path.join(project_root, "requirements.txt"), "requirements.txt")
PYEOF

az webapp deploy \
  --name "expeditors-${userName}-metals-api" \
  --resource-group "expeditors-${userName}-metals-rg" \
  --src-path "$DEPLOY_ZIP" \
  --type zip

#####################
# Logging
#####################
az webapp log config --name "expeditors-${userName}-metals-api" --resource-group "expeditors-${userName}-metals-rg" --application-logging filesystem --level information


az webapp log tail --name "expeditors-${userName}-metals-api" --resource-group "expeditors-${userName}-metals-rg"
