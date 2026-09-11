# Manual Azure deployment scripts

Use these scripts for the manual Azure deployment process. Run the examples
below in **PowerShell from the repository root**, not from `utility_scripts`.
This guide documents the scripts as they currently work.

## Script status

| Script | Purpose | Current status |
| --- | --- | --- |
| [az_create_resources.ps1](az_create_resources.ps1) | Create PostgreSQL, Azure Container Registry, and the API, UI, and tutorials container Web Apps | Updated for containers |
| [az_deploy.ps1](az_deploy.ps1) | Build all three images in ACR, point the Web Apps at them, and restart | Updated for containers |
| [az_setup_github_oidc.ps1](az_setup_github_oidc.ps1) | Configure GitHub Actions authentication to Azure | Optional; grants access to the API Web App only, not registry push or UI deployment |
| [az_delete_resources.ps1](az_delete_resources.ps1) | Delete the resource group and everything inside it | Supports preview with `-WhatIf` |

The `.sh` files are Bash equivalents of the PowerShell scripts above, for
macOS/Linux/Git Bash use, and take the same options in `--kebab-case` form
(for example `--user-name`, `--skip-provisioning`). Terraform and the GitHub
deployment workflow still use the earlier source-code deployment model. Use
one provisioning approach for a resource group; switching approaches does not
automatically import existing resources into Terraform state.

## 1. Prepare your terminal

You need:

- PowerShell 5.1 or later.
- Azure CLI (`az`) installed and available on your PATH.
- An Azure subscription and permission to create resources and assign Azure
  roles. The creation script grants each Web App's managed identity `AcrPull`
  on the registry.
- Either PostgreSQL's `psql` client or Python with `psycopg` for initializing
  the database. Docker is not required to run the creation script.

Check your tools:

```powershell
$PSVersionTable.PSVersion
az --version
```

If using the project's Python environment, install its dependencies if needed:

```powershell
.\.venv\Scripts\python.exe -m pip install -r .\requirements.txt
```

The creation script looks for `psql` on PATH and in standard Windows PostgreSQL
installation directories. If it cannot find `psql`, it looks for Python with
`psycopg`, starting with `.venv\Scripts\python.exe`. You do not have to activate
the virtual environment for that lookup.

If PowerShell blocks a script you have reviewed, allow it for this terminal
session only, then rerun the command:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## 2. Log in and select your subscription

The scripts **do not run `az login` or prompt for Azure sign-in**. Log in first:

```powershell
az login
az account show --output table
```

If necessary, select the subscription you intend to use:

```powershell
az account list --output table
az account set --subscription "<subscription name or ID>"
az account show --output table
```

Verify the account and subscription before provisioning. The creation script
uses the active Azure CLI subscription and creates billable Azure resources.

## 3. Create resources for the first time

When no database exists, run without `-SkipProvisioning`:

```powershell
.\utility_scripts\az_create_resources.ps1 -UserName dzierzon
```

The script prompts for the **new PostgreSQL administrator password**. Save it
for future database access and resumed runs. This is separate from your Azure
login and from application users' passwords. The database administrator is
`metalsadmin`; the application database is `metals`.

The script performs these steps in order:

1. Check tools, Azure authentication, and the local public IPv4 address.
2. Create the resource group, PostgreSQL Flexible Server, and `metals` database.
3. Allow the local client IP through the database firewall. The development
   setup also allows connections from Azure services.
4. Load `sql/metals-db.sql` if the database has no public base tables. If any
   already exist, skip initialization and preserve them; this is not a schema
   migration or repair operation.
5. Create a Basic Azure Container Registry and a shared B1 Linux App Service plan.
6. Create or configure the API, UI, and tutorials container Web Apps, with managed
   identities allowed to pull images from the registry.
7. Configure HTTPS, logging, `/health` checks, container ports, database settings,
   a JWT signing key, and the UI's API upstream URL.
8. Print the registry, expected image names, and application URLs.

With the default username, resource names are:

| Resource | Name |
| --- | --- |
| Resource group | `expeditors-dzierzon-metals-rg` |
| PostgreSQL server | `expeditors-dzierzon-metals-pg` |
| Container registry | `expeditorsdzierzonmetalsacr` |
| App Service plan | `expeditors-dzierzon-metals-appservice-plan` |
| API Web App | `expeditors-dzierzon-metals-api` |
| UI Web App | `expeditors-dzierzon-metals-ui` |
| Tutorials Web App | `expeditors-dzierzon-metals-tutorials` |

**This runs all steps automatically.** It does not pause for verification
between resources and has no step-selection parameter. For individual execution,
review the script's setup variables and `Invoke-Az` helper before running its
command blocks in order. Later blocks depend on earlier variables and resources.
The verification commands below can be run separately without changing resources.

### Creation parameters

| Parameter | Use |
| --- | --- |
| `-UserName` | Resource-name suffix; default `dzierzon`. Use the same value in all scripts. |
| `-Location` | Azure region; default `westus2`. |
| `-RegistryName` | Override the generated registry name, for example if it is already taken. Must contain 5–50 letters or digits. |
| `-ImageTag` | Expected tag for every image; default `latest`. This does not build or push images. |
| `-DatabasePassword` | Optional `SecureString`; otherwise the script prompts. |
| `-ClientIp` | Explicit public IPv4 address if automatic detection fails or a VPN changes database egress. |
| `-PsqlPath` | Full path to a `psql` executable. |
| `-SkipProvisioning` | Skip creation of the resource group, PostgreSQL server, and database only. Other steps still run. |

Example with an explicit database client:

```powershell
.\utility_scripts\az_create_resources.ps1 -UserName dzierzon `
    -PsqlPath "C:\Program Files\PostgreSQL\16\bin\psql.exe"
```

Use the actual installation path on your machine.

## 4. Verify the resources

Set these variables to match your run:

```powershell
$resourceGroup = "expeditors-dzierzon-metals-rg"
$dbServer = "expeditors-dzierzon-metals-pg"
$apiApp = "expeditors-dzierzon-metals-api"
$uiApp = "expeditors-dzierzon-metals-ui"
$registryName = "expeditorsdzierzonmetalsacr"
```

Inspect the resource inventory, database, and client firewall rules:

```powershell
az resource list --resource-group $resourceGroup --output table
az postgres flexible-server show --resource-group $resourceGroup --name $dbServer --query "{Name:name,State:state,Host:fullyQualifiedDomainName}" --output table
az postgres flexible-server db list --resource-group $resourceGroup --server-name $dbServer --output table
az postgres flexible-server firewall-rule list --resource-group $resourceGroup --name $dbServer --output table
```

To verify the seeded tables using `psql` (it prompts for the database password):

```powershell
psql "host=$dbServer.postgres.database.azure.com port=5432 dbname=metals user=metalsadmin sslmode=require" -W -c "SELECT count(*) FROM elements;"
```

If `psql` is not on PATH, invoke its full path with PowerShell's `&` operator.
You can also use your PostgreSQL GUI client with the same host, database, user,
and SSL requirement.

Inspect the registry, images selected for the Web Apps, and assigned pull roles:

```powershell
az acr show --name $registryName --resource-group $resourceGroup --query "{Name:name,Server:loginServer,AdminEnabled:adminUserEnabled}" --output table
az webapp config show --resource-group $resourceGroup --name $apiApp --query "{Image:linuxFxVersion,ManagedIdentityPull:acrUseManagedIdentityCreds,HealthPath:healthCheckPath}" --output table
az webapp config show --resource-group $resourceGroup --name $uiApp --query "{Image:linuxFxVersion,ManagedIdentityPull:acrUseManagedIdentityCreds,HealthPath:healthCheckPath}" --output table
$registryId = az acr show --name $registryName --resource-group $resourceGroup --query id --output tsv
az role assignment list --scope $registryId --query "[].{Role:roleDefinitionName,Principal:principalId}" --output table
```

Successful resource creation does not mean the applications are serving traffic.
The selected images must exist in the registry before the Web Apps can run them.

## 5. Resume after a failure or reuse an existing database

If the resource group, PostgreSQL server, and `metals` database all exist:

```powershell
.\utility_scripts\az_create_resources.ps1 -UserName dzierzon -SkipProvisioning
```

Enter the database's **existing** administrator password. This switch does not
reset it. Supply the same custom registry name and image tag if you used them
on the original run. An existing JWT signing key is retained as well.

If database initialization times out, allow up to five minutes for firewall
changes to propagate. Check outbound TCP port 5432 and, when appropriate,
supply `-ClientIp` with the public IPv4 address used by your VPN/proxy.

`-SkipProvisioning` still configures the container apps and their settings. It
is not a read-only check. Use the verification commands above to inspect a live
deployment without changing it. Use the deployment process, rather than this
provisioning script, for routine code updates.

## 6. Deploy application images

The creation script expects these repositories in your Azure Container Registry:

```text
<registry-login-server>/metals-api:<ImageTag>
<registry-login-server>/metals-ui:<ImageTag>
<registry-login-server>/metals-tutorials:<ImageTag>
```

Build and deploy all three images with:

```powershell
.\utility_scripts\az_deploy.ps1 -UserName dzierzon
```

This builds each image in Azure Container Registry with `az acr build` (no
local Docker required), points each Web App at the new tag, restarts them so
they actually re-pull the image, and polls `/health` until each app responds
or the attempt times out. Use `-ImageTag` to deploy a tag other than `latest`,
`-SkipBuild` to only repoint and restart Web Apps at an already-pushed tag,
and `-FollowLogs` to stream the API's container logs after restarting (add
`-UserName` again with `az webapp log tail --name <ui-app-name>` for the UI).
Rerunning is safe; it always rebuilds and restarts all three apps.

After images have been deployed, verify the actual hostnames and health endpoints:

```powershell
$apiHost = az webapp show --resource-group $resourceGroup --name $apiApp --query defaultHostName --output tsv
$uiHost = az webapp show --resource-group $resourceGroup --name $uiApp --query defaultHostName --output tsv
Invoke-RestMethod "https://$apiHost/health"
Invoke-RestMethod "https://$uiHost/health"
Start-Process "https://$uiHost"
```

The health endpoints check each HTTP server, not database connectivity. Verify
login and catalog access through the UI as well. To inspect container logs:

```powershell
az webapp log tail --resource-group $resourceGroup --name $apiApp
```

Press Ctrl+C to stop following logs. Substitute `$uiApp` to inspect UI logs.

## Optional: GitHub Actions authentication

Manual provisioning does not require GitHub OIDC. The existing setup script
creates a federated identity and grants `Website Contributor` on the API app:

```powershell
.\utility_scripts\az_setup_github_oidc.ps1 -UserName dzierzon
```

It prints the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`
values to add to the GitHub `Development` environment. Its default subject is
specific to this repository. For another repository, provide `-Repository` and
the exact `-FederatedSubject` used by GitHub's Azure login step.

To repair just an existing federated credential:

```powershell
.\utility_scripts\az_setup_github_oidc.ps1 -UserName dzierzon `
    -UpdateCredentialOnly -FederatedSubject "<exact subject from the login log>"
```

This script and the workflow need further updates for registry push permission
and deployment of all three containers. The existing API-only role is insufficient
for that complete workflow.

## Delete the environment

Preview the target first:

```powershell
.\utility_scripts\az_delete_resources.ps1 -UserName dzierzon -WhatIf
```

To actually delete it:

```powershell
.\utility_scripts\az_delete_resources.ps1 -UserName dzierzon
```

**Deletion removes the entire resource group, including PostgreSQL data, the
container registry and its images, all three Web Apps, and the App Service plan.**
The script waits for deletion to finish. Use `-Subscription "<name or ID>"` to
explicitly select the target subscription, and `-Confirm` if you want an
interactive confirmation prompt. This operation is separate from Docker
Compose on your local computer.
