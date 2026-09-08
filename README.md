# Metals API: Azure deployment guide

Start here when no Azure resources exist. Complete the steps in this order:
**create resources → configure OIDC → add GitHub secrets and environment → push code → verify build, test, and deployment**.

The commands below use PowerShell from the repository root and the scripts' default username, `dzierzon`.

## Before starting

- Install Git, Azure CLI, and Python 3.11. Use PowerShell 5.1 or later.
- Have access to the Azure subscription, including permission to create resources, managed identities, and role assignments on the App Service.
- Have permission to manage this repository's GitHub secrets and environments.
- Install the Python dependencies. The resource script uses `psql` if available, otherwise Python with `psycopg`.

```powershell
python -m pip install -r requirements.txt
az login
az account show --output table
```

If the displayed subscription is not the intended one, select it before continuing:

```powershell
az account set --subscription "<your-subscription-id>"
```

## 1. Create the Azure resources

```powershell
.\utility_scripts\az_create_resources.ps1
```

Wait for the entire script to finish successfully. It creates:

| Resource | Default name |
| --- | --- |
| Resource group | `expeditors-dzierzon-metals-rg` |
| PostgreSQL Flexible Server | `expeditors-dzierzon-metals-pg` |
| PostgreSQL database | `metals` |
| App Service plan | `expeditors-dzierzon-metals-appservice-plan` |
| Web App | `expeditors-dzierzon-metals-api` |

It also configures database firewall access, loads `sql/metals-db.sql`, and sets the Web App's Python 3.11 runtime, startup command, and application settings.

At the PostgreSQL username prompt, press Enter to accept `metalsadmin`. At the password prompt, enter the same password used by the script's `--admin-password` setting. The prompt configures the connection URL; it does not reset the database password.

If you use a different `-UserName`, use that same value for the OIDC script and update `AZURE_WEBAPP_NAME` in [the workflow](.github/workflows/azure-webapps-python.yml).

## 2. Configure Azure authentication for GitHub Actions

After resource creation succeeds, run:

```powershell
.\utility_scripts\az_setup_github_oidc.ps1
```

This creates a user-assigned managed identity, a federated credential that trusts this repository's `Development` environment, and a `Website Contributor` role assignment scoped to the Web App.

The script prints these three values for the next step:

```text
AZURE_CLIENT_ID = ...
AZURE_TENANT_ID = ...
AZURE_SUBSCRIPTION_ID = ...
```

Use the full setup command for a new deployment. `-UpdateCredentialOnly` repairs an existing credential and does not create the identity or its role assignment.

The default federated subject includes this repository's owner and repository IDs. For a different repository, pass `-Repository` and `-FederatedSubject` with that repository's exact GitHub OIDC subject.

## 3. Add the GitHub secrets and environment

Open [the repository's Actions secrets settings](https://github.com/gdzierzon/cohort-d-dzierzong-metals-simple-deploy/settings/secrets/actions).

Navigate to **Settings → Secrets and variables → Actions → Secrets → New repository secret**. Add each secret separately, copying only its value from the OIDC script output:

| Secret name | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Managed identity client ID printed by the script |
| `AZURE_TENANT_ID` | Tenant ID printed by the script |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID printed by the script |

Use repository **secrets**, not the Variables tab. No publish profile, client secret, or `AZURE_WEBAPP_PUBLISH_PROFILE` is needed with this workflow. Basic authentication can remain disabled.

Next, go to **Settings → Environments → New environment**. Enter **`Development`** exactly and click **Configure environment**. If it already exists, keep it. The workflow and Azure federated credential both reference this name. The three secrets can remain at repository level.

Allow a few minutes for the Azure identity configuration and role assignment to propagate before triggering deployment.

## 4. Commit and push the code to trigger GitHub Actions

Complete the Azure and GitHub setup above before pushing the deployment changes.

Review your changes, stage the changed tracked files, then commit and push the current branch:

```powershell
git status
git diff
git add -u
git diff --cached
git commit -m "Configure Azure deployment with GitHub OIDC"
git push -u origin HEAD
```

For any new files shown as untracked, stage them explicitly with `git add path/to/file` before committing. Keep local `.env` files and credentials out of commits.

The workflow runs on every branch push. You do not need to merge into the default branch to trigger it. Subsequent code changes follow the same commit-and-push process; resource creation and OIDC setup are not required for each deployment.

## 5. Verify build, test, and deployment

In GitHub, open **Actions → Build and deploy Python app to Azure Web App**, then select the run for your commit.

- **build** installs dependencies and packages the application with `app.py` and `requirements.txt` at the deployment root.
- **test** starts a separate PostgreSQL 16 service on the GitHub runner, loads the schema, and runs the tests.
- **deploy** waits for both jobs to succeed, logs in to Azure through OIDC, and deploys the build artifact to the Web App. Any configured `Development` environment approval must also be satisfied.

Build and test can run in parallel. The test job uses its own database, not your Azure database.

After deployment succeeds, open the application URL shown in the deployment job or in the Azure Web App's Overview page. Ensure the Azure PostgreSQL server is running when using database-backed endpoints.

For an unchanged commit that failed because of an Azure or GitHub setting, fix the setting and use **Re-run failed jobs**. If you changed the workflow or application code, commit and push those changes to create a new run; rerunning an old run uses the old commit.

## Resuming a partial resource setup

If the resource group, PostgreSQL server, and `metals` database already exist, but the resource script failed at or after the firewall step:

```powershell
.\utility_scripts\az_create_resources.ps1 -SkipProvisioning
```

This resumes at firewall configuration and continues through database initialization and App Service setup. Database initialization drops and recreates the application tables, so use this for initial setup recovery, not routine code deployment.

If the database connection times out immediately after adding the firewall rule, allow up to five minutes for propagation. The script accepts `-ClientIp` if your VPN or proxy requires an explicit public IPv4 address.

## Repairing an OIDC subject mismatch

For an existing identity that fails login with `AADSTS700213`, compare the subject in the GitHub login log with the Azure federated credential. For this repository's current subject, run:

```powershell
.\utility_scripts\az_setup_github_oidc.ps1 -UpdateCredentialOnly
```

If the subject differs from the script's default, also pass `-FederatedSubject '<exact subject from the login log>'`. Wait a few minutes, then rerun the failed job. Updating only the federated credential does not change the GitHub secrets.

## Deleting everything and starting over

Preview the deletion, then delete the resource group and all its contents, including database data:

```powershell
.\utility_scripts\az_delete_resources.ps1 -WhatIf
.\utility_scripts\az_delete_resources.ps1
```

Wait for deletion to complete, then repeat steps 1–5. Deletion also removes the GitHub managed identity and federated credential. Run the full OIDC setup again and replace GitHub's `AZURE_CLIENT_ID` with the new value. Verify the other two secrets against the new output; they stay the same if the tenant and subscription are unchanged. The existing GitHub `Development` environment can be reused.
