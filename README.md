# Metals API: Terraform and GitHub Actions demo

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
