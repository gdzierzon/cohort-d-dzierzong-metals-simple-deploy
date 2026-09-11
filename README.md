# Metals API: Terraform and GitHub Actions demo

## Run the UI and API with Docker

Start Docker Desktop using Linux containers. Run these commands from the repository root in PowerShell (or a WSL terminal).

If you do not already have a `.env` file, copy `.env.example` to `.env`. Set `JWT_SECRET_KEY` to a long random secret; generate one with:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

Build and start the UI, API, and PostgreSQL:

```powershell
docker compose up --build -d
docker compose ps
curl.exe http://localhost:5000/health
```

Open **http://localhost:8888** for the Metals UI. Its Nginx container serves
the static files and forwards `/api` requests to the API container. Set
`UI_PORT=8889` in `.env` if port 8888 is occupied. See the
[UI Docker instructions](metals_ui/README.md#run-with-docker) for standalone use.

The health endpoint returns `{"status":"ok"}` when the HTTP server is running; it does not check the database. API routes are under `http://localhost:5000/api`, and protected routes still require a JWT. Set `API_PORT=5001` in `.env` if port 5000 is already occupied.

Compose connects the API to `db:5432` using the existing local demo database credentials (`postgres` / `postgres`, database `metals`). It intentionally overrides the host/database variables in `.env`, which can still be used when running Python directly on Windows. PostgreSQL data stays in the existing `pgdata_metals` volume. The SQL initialization script runs only when that volume is empty.

```powershell
docker compose logs -f api
docker compose down
```

`down` preserves database data. `down -v` deletes the database volume and its data. To debug the API directly in VS Code, stop the API container with `docker compose stop api` and leave the database running.

### Build an image for deployment

```powershell
docker build -f metals_api/Dockerfile -t metals-api:1.0 .
docker run --name metals-api --env-file .env -p 5000:5000 -d metals-api:1.0
```

For standalone `docker run`, set all `DB_*` values in the supplied environment file to your target database. `localhost` inside a container refers to that container; use `host.docker.internal` to reach a database exposed on your Windows host through Docker Desktop. Stop the Compose API first if it uses the same host port.

The image serves Flask through Gunicorn as a non-root user on port 5000. Secrets are supplied at runtime and excluded from the build context. Deploy the image to a container host with database connectivity, runtime environment variables, and HTTPS ingress. The Compose database credentials are for local development. Existing Azure workflows still deploy Python source; they have not been converted to container deployment.

## Existing Azure deployment workflow

This branch teaches Azure infrastructure provisioning and application deployment using two independent GitHub Actions workflows.

- [Terraform infrastructure](.github/workflows/terraform.yml): automatic validation for infrastructure changes, plus manually selected **plan**, **apply**, and **destroy** operations.
- [Application build/test/deploy](.github/workflows/azure-webapps-python.yml): packages and tests Python code, then deploys to the existing Azure Web App.

Follow the [step-by-step Terraform guide](terraform/README.md):

1. Run the one-time [bootstrap Terraform configuration](terraform/bootstrap/main.tf) locally to create the infrastructure identity and state storage.
2. Configure GitHub's **Terraform** and **Development** environments, infrastructure secrets, and variables.
3. Migrate any existing local Terraform state to Azure Blob Storage before running infrastructure against existing resources.
4. Run **Terraform infrastructure → plan**, then **apply**. The workflow can initialize an empty database without resetting existing demo data.
5. Copy application deployment IDs from the run summary into the `AZURE_*` GitHub secrets.
6. Push application code or manually run the application workflow.

The application **destroy** operation preserves the bootstrap identity and state storage so the demo can be recreated through Actions. Recreating the application identity requires updating its `AZURE_CLIENT_ID`; the infrastructure `TF_AZURE_*` secrets remain unchanged.

The original Azure CLI scripts belong to the manual-provisioning lesson. Terraform now manages the application resources in this branch. Switching Git branches does not delete or import Azure resources.

## Manual-provisioning scripts

The manual Azure CLI lesson has equivalent PowerShell and Bash scripts. Authenticate first with `az login`, then choose the command for your shell:

| Task | PowerShell | Bash |
| --- | --- | --- |
| Create resources | `.\utility_scripts\az_create_resources.ps1` | `bash utility_scripts/az_create_resources.sh` |
| Configure GitHub OIDC | `.\utility_scripts\az_setup_github_oidc.ps1` | `bash utility_scripts/az_setup_github_oidc.sh` |
| Deploy the application | `.\utility_scripts\az_deploy.ps1` | `bash utility_scripts/az_deploy.sh` |
| Preview deletion | `.\utility_scripts\az_delete_resources.ps1 -WhatIf` | `bash utility_scripts/az_delete_resources.sh --what-if` |
| Delete resources | `.\utility_scripts\az_delete_resources.ps1` | `bash utility_scripts/az_delete_resources.sh` |
