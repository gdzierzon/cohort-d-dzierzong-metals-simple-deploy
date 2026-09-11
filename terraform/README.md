# Terraform infrastructure through GitHub Actions

This branch has two independent workflows:

| Workflow | Purpose | Trigger |
| --- | --- | --- |
| `terraform.yml` — **Terraform infrastructure** | Validate, plan, create/update, initialize an empty database, or destroy application infrastructure | Validation on Terraform pushes/PRs; Azure operations through **Run workflow** |
| `azure-webapps-python.yml` — **Build and deploy Python app to Azure Web App** | Build, test, and deploy application code | Application-related pushes or **Run workflow** |

Infrastructure-only commits no longer trigger application deployment. Terraform state is stored in Azure Blob Storage with locking. A separate bootstrap resource group holds the state storage and infrastructure identity so application teardown does not delete them.

## 1. Run the one-time bootstrap locally

Start with an Azure account that can create resources and assign subscription-level roles, such as a subscription Owner. Install Terraform 1.7 or later and Azure CLI. The workflows use Terraform 1.16.0.

From the repository root, use either shell.

**PowerShell**
```powershell
az login
az account show --output table
$env:TF_VAR_subscription_id = (az account show --query id --output tsv)
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -out bootstrap.tfplan
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
terraform -chdir=terraform/bootstrap output
```

**Bash**
```bash
az login
az account show --output table
export TF_VAR_subscription_id="$(az account show --query id --output tsv)"
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -out bootstrap.tfplan
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
terraform -chdir=terraform/bootstrap output
```

Review the plan before applying it. Applying a saved plan executes it without another prompt. To use another subscription, run `az account set --subscription "<id>"` before capturing the subscription ID.

Bootstrap creates:

- `expeditors-dzierzon-terraform-rg`, separate from the application group.
- A private state container in an Azure Storage account, with blob versioning and a 7-day deletion-retention policy. Storage access uses Microsoft Entra authentication, not access keys.
- A GitHub identity that trusts this repository's exact OIDC subject for the **Terraform** environment.
- Subscription-level **Contributor** so the workflow can create and remove the application resource group and its resources.
- **Role Based Access Control Administrator**, conditioned to assign/remove only **Website Contributor** roles for service principals, so Terraform can manage the application deployment identity's role.
- **Storage Blob Data Contributor** on the state container for the workflow identity and the local bootstrap operator.

Use a dedicated teaching subscription: the infrastructure identity has broader access than the application deployment identity. Restrict the GitHub **Terraform** environment to trusted deployment branches; configure reviewers if your lesson needs approval before changes.

Bootstrap uses its own local `terraform/bootstrap/terraform.tfstate`. Keep it private and retain it. The application workflow never applies or destroys the bootstrap module. For a different repository, supply `github_subject_repository` to both configurations, including immutable IDs when present. The defaults match this repository.

## 2. Configure GitHub before running infrastructure

In **Settings → Environments**, create these case-sensitive environments:

- **Terraform** — infrastructure workflow.
- **Development** — application deployment workflow.

### Terraform environment only

All `TF_*` values in this section belong **only** in the **Terraform** environment. Do not add them as repository-level values and do not copy them into the **Development** environment.

Open **Settings → Environments → Terraform**, then add these environment secrets:

| Secret | Value |
| --- | --- |
| `TF_AZURE_CLIENT_ID` | Bootstrap `github_secrets` output |
| `TF_AZURE_TENANT_ID` | Bootstrap `github_secrets` output |
| `TF_AZURE_SUBSCRIPTION_ID` | Bootstrap `github_secrets` output |
| `TF_DB_PASSWORD` | Choose the PostgreSQL admin password; retain the same value across runs |

Still in **Settings → Environments → Terraform**, add these environment variables:

| Variable | Value |
| --- | --- |
| `TF_STATE_STORAGE_ACCOUNT` | Bootstrap `github_variables` output |
| `TF_CLIENT_IP` | Your public IPv4 address, without `/32`; used for your persistent database firewall rule |
| `TF_USER_NAME` | Bootstrap output; optional, default `dzierzon` |
| `TF_LOCATION` | Bootstrap output; optional, default `westus2` |

Find your public IPv4 address with either `Invoke-RestMethod https://api4.ipify.org` in PowerShell or `curl -fsSL https://api4.ipify.org` in Bash. If using a VPN/proxy, use your database connection's egress IP. A changing GitHub runner IP is handled separately using a temporary rule.

The `TF_AZURE_*` identity provisions infrastructure. It is different from the `AZURE_*` identity used for application deployment; do not replace one set with the other. The storage container and blob key are fixed to `tfstate` and `metals.tfstate` in the workflow, so all branches operate on the same application state. Workflow concurrency and backend locking serialize infrastructure operations.

The **Development** environment needs no values yet. Step 5 adds the separate `AZURE_*` deployment secrets there after Terraform creates the application identity.

Allow a few minutes for identity and role assignments to propagate.

## 3. Handle any existing resources or local state

**Fresh deployment:** continue to step 4 if no same-named application resources exist.

**Previously applied Terraform locally:** migrate the existing application state before running the workflow. Do not start an empty remote state against existing resources.

Copy `terraform/backend.hcl.example` to `terraform/backend.hcl`, then replace its storage account placeholder with the bootstrap output. Authenticate with the same local operator granted state access during bootstrap:

**PowerShell**
```powershell
terraform -chdir=terraform init -migrate-state -backend-config backend.hcl
```

**Bash**
```bash
terraform -chdir=terraform init -migrate-state -backend-config backend.hcl
```

Confirm the state-copy prompt. Verify `terraform -chdir=terraform state list` shows the existing resources. Match `TF_DB_PASSWORD` to the password used previously, and match the GitHub variables to your existing local inputs. Keep the local backup until migration is verified.

**Resources from the manual Azure demo:** Terraform does not automatically adopt resources when you switch branches. Explicitly import each resource, or remove the old demo and wait for deletion before applying. Importing only the resource group is insufficient.

State and saved plans contain the database password even though Terraform marks it sensitive. State, plans, local `.tfvars`, and `backend.hcl` are ignored by Git. Commit both `.terraform.lock.hcl` files. Plans are not uploaded as GitHub artifacts.

## 4. Commit the workflow, then run plan/apply

Commit the new workflow, Terraform files, lock files, and documentation. Do not commit local inputs, credentials, or state. A `workflow_dispatch` workflow must exist on the repository's default branch to expose **Run workflow**; once registered, select the desired branch for the demo.

Open **Actions → Terraform infrastructure → Run workflow**:

1. Select the branch containing this configuration.
2. Select **plan** first and inspect the Terraform log. This reads Azure and remote state but does not apply resource changes.
3. Run again with **apply** to create/update the infrastructure. Leave **initialize_database** checked for initial setup.

Each apply run generates its own fresh plan and applies that plan in the same job. A prior plan-only run is a preview, not a saved approval artifact used by the later run. The operation defaults to plan; pushes and pull requests run offline checks only and never apply or destroy Azure resources.

Apply creates: PostgreSQL 16/B1ms with 32 GiB storage and 7-day backups, the `metals` database and firewall rules, a Basic Azure Container Registry, a shared Linux B1 App Service plan with separate API and UI container Web Apps (pulling `metals-api`/`metals-ui` via each app's own managed identity, not admin credentials), application settings, and the Development OIDC deployment identity (now scoped to both Web Apps plus `AcrPush` on the registry). Basic publishing authentication remains disabled.

Apply does **not** build or push the container images. Push `metals-api:<image_tag>` and `metals-ui:<image_tag>` to the output `container_registry_login_server` first — e.g. with `az_deploy.ps1`/`az_deploy.sh` — using the same `image_tag` value (default `latest`) you pass to Terraform; an apply that changes `image_tag` also restarts the Web Apps against the new tag, an apply that doesn't still requires a manual restart for Azure to re-pull `:latest`. **The `azure-webapps-python.yml` application workflow has not been updated for this model** — it still does a ZIP deploy of the old Python-runtime app and does not deploy the UI at all; treat it as disabled (its triggers are already commented out) until it's rewritten to build/push both images and restart both Web Apps.

After apply, the workflow temporarily permits the runner's single IPv4 address, loads `sql/metals-db.sql` into an empty database, and removes the temporary firewall rule in a cleanup step. If all four demo tables already exist, it preserves them and succeeds. A partially existing schema fails instead of resetting data. This is demo initialization, not a database migration system.

The cleanup runs even if initialization fails. If a runner is forcibly lost or terminated before cleanup can run, inspect and remove any leftover `GitHubRunner-*` firewall rule before continuing. The persistent `TF_CLIENT_IP` rule is managed by Terraform.

A failed apply can leave successfully created resources tracked in state. Fix the error and rerun **apply**; no manual skip-provisioning mode is required.

## 5. Configure application deployment and run it

After successful infrastructure apply, open the run summary's **Application workflow settings**. In the **Development** environment, add the generated IDs as environment secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

To display the same values locally from the shared Terraform state, first initialize the remote backend as described in [Optional local Terraform and schema operations](#optional-local-terraform-and-schema-operations). Copy `backend.hcl.example` to the ignored `backend.hcl`, replace `COPY-TF_STATE_STORAGE_ACCOUNT-FROM-BOOTSTRAP` with the `TF_STATE_STORAGE_ACCOUNT` value from the **Terraform** environment, and run `terraform init`. Then run:

**PowerShell**
```powershell
.\terraform\scripts\show_application_deployment_secrets.ps1
```

**Bash**
```bash
bash terraform/scripts/show_application_deployment_secrets.sh
```

Keep `TF_AZURE_*` secrets unchanged. The workflow prints only identifiers, not the database password. GitHub secret updates are performed manually; the infrastructure workflow is not given repository-secret write permissions.

Ensure `AZURE_WEBAPP_NAME` in `.github/workflows/azure-webapps-python.yml` matches the Web App name shown in the summary, especially if you changed `TF_USER_NAME`.

Now push application code changes or select **Run workflow** on **Build and deploy Python app to Azure Web App**. Build and test run in parallel; deploy waits for both and authenticates using the Development identity. Running Terraform does not automatically trigger this workflow. Updates to the application workflow file itself are run manually so an infrastructure-setup commit cannot accidentally deploy before its Development identity exists. If an earlier application run failed before its identity/secrets existed, rerun it after setup.

## 6. Update or destroy infrastructure independently

For an infrastructure edit, commit it and run **plan**, then **apply**. For application-only edits, push the code; Terraform does not need to run.

To delete the application infrastructure and all its database data, select **destroy** from the Terraform workflow. It produces a destroy plan and executes it in that run. The bootstrap group, state storage, and infrastructure identity remain available.

To recreate the demo, run **apply** with database initialization enabled. Update the application `AZURE_CLIENT_ID` from the new summary, verify the other `AZURE_*` values, then run application deployment. The `TF_AZURE_*` secrets and state-storage variable stay valid because the bootstrap resources survived.

For complete final cleanup, destroy the application first, then use the retained bootstrap state locally to plan and destroy `terraform/bootstrap`. Destroying bootstrap removes the infrastructure workflow's authentication and state storage; it is not part of routine demo reset.

## Optional local Terraform and schema operations

Use the same remote backend as Actions. Copy `terraform/backend.hcl.example` to the ignored `terraform/backend.hcl`, replace `COPY-TF_STATE_STORAGE_ACCOUNT-FROM-BOOTSTRAP` with the `TF_STATE_STORAGE_ACCOUNT` value from the **Terraform** environment, and authenticate with `az login`. Set normal inputs using local `.tfvars` or `TF_VAR_*` environment variables. Supply `TF_VAR_db_password` without committing it. If local state needs migration, use step 3 instead of an ordinary init.

**PowerShell**
```powershell
Copy-Item .\terraform\backend.hcl.example .\terraform\backend.hcl
terraform -chdir=terraform init -backend-config backend.hcl
terraform -chdir=terraform plan
```

**Bash**
```bash
cp terraform/backend.hcl.example terraform/backend.hcl
terraform -chdir=terraform init -backend-config backend.hcl
terraform -chdir=terraform plan
```

Do not run a local apply concurrently with the workflow. `terraform output -json github_secrets` retrieves the application IDs from shared state. The initializer can still be run locally:

**PowerShell**
```powershell
python -m pip install -r requirements.txt
python terraform/scripts/initialize_database.py --skip-existing
```

**Bash**
```bash
python3 -m pip install -r requirements.txt
python3 terraform/scripts/initialize_database.py --skip-existing
```

`--reset` explicitly drops and reloads existing demo tables; it is never passed by the workflow.

## Offline verification

After downloading the providers, these checks do not create Azure resources:

**PowerShell**
```powershell
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform test
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
python -m unittest discover -s terraform/tests -p "test_*.py"
```

**Bash**
```bash
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform test
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
python3 -m unittest discover -s terraform/tests -p 'test_*.py'
```

The Terraform tests use a mock provider, including their mock apply. They do not establish whether live Azure permissions, name availability, capacity, or OIDC login will succeed; verify those with the real workflow after bootstrap.

References: [AzureRM backend and OIDC](https://developer.hashicorp.com/terraform/language/backend/azurerm), [Azure role-assignment conditions](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-overview).
