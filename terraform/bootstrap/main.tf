# Run once locally with an Azure administrator account.
# This root module deliberately has separate state from the application.
terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.2.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  resource_providers_to_register = [
    "Microsoft.Storage", "Microsoft.ManagedIdentity",
    "Microsoft.Web", "Microsoft.DBforPostgreSQL",
  ]
}

variable "subscription_id" {
  type = string
}

variable "user_name" {
  type    = string
  default = "dzierzon"
}

variable "location" {
  type    = string
  default = "westus2"
}

variable "github_subject_repository" {
  type    = string
  default = "gdzierzon@9723466/cohort-d-dzierzong-metals-simple-deploy@1361521533"
}

data "azurerm_client_config" "current" {}

locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_resource_group" "bootstrap" {
  name     = "expeditors-${var.user_name}-terraform-rg"
  location = var.location
}

resource "azurerm_storage_account" "state" {
  name                            = "tfmetals${substr(sha256("${var.subscription_id}/${var.user_name}"), 0, 16)}"
  resource_group_name             = azurerm_resource_group.bootstrap.name
  location                        = azurerm_resource_group.bootstrap.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "terraform" {
  name                = "expeditors-${var.user_name}-terraform-github"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
}

resource "azurerm_federated_identity_credential" "terraform" {
  name                      = "github-terraform"
  user_assigned_identity_id = azurerm_user_assigned_identity.terraform.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "repo:${var.github_subject_repository}:environment:Terraform"
}

# Subscription scope is needed because the application resource group itself
# is created/destroyed by the workflow. Use a dedicated teaching subscription.
resource "azurerm_role_assignment" "infrastructure" {
  scope                = local.subscription_scope
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"
}

# Permit assigning/removing ONLY Website Contributor to service principals.
# The workflow cannot use this assignment to grant Owner or Contributor.
resource "azurerm_role_assignment" "deployment_roles" {
  scope                = local.subscription_scope
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-CONDITION
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
      OR
      (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {de139f84-1756-47ae-9be6-808fbbe84772}
        AND @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
    AND
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
      OR
      (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {de139f84-1756-47ae-9be6-808fbbe84772}
        AND @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
  CONDITION
}

resource "azurerm_role_assignment" "state_workflow" {
  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"
}

# Allows the bootstrap operator to migrate existing state and run Terraform locally.
resource "azurerm_role_assignment" "state_operator" {
  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "github_secrets" {
  value = {
    TF_AZURE_CLIENT_ID       = azurerm_user_assigned_identity.terraform.client_id
    TF_AZURE_TENANT_ID       = azurerm_user_assigned_identity.terraform.tenant_id
    TF_AZURE_SUBSCRIPTION_ID = var.subscription_id
  }
}

output "github_variables" {
  value = {
    TF_STATE_STORAGE_ACCOUNT = azurerm_storage_account.state.name
    TF_USER_NAME             = var.user_name
    TF_LOCATION              = var.location
  }
}
