# Uses a mock provider: even the apply below never creates Azure resources.
mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pg"
      fqdn = "test-pg.postgres.database.azure.com"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test/providers/Microsoft.Web/serverFarms/test-plan"
    }
  }
  mock_resource "azurerm_linux_web_app" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test/providers/Microsoft.Web/sites/test-app"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-identity"
      principal_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000001"
  client_ip       = "203.0.113.10"
  db_password     = "Test @Password+123"
}

run "matches_powershell_resources" {
  command = apply

  assert {
    condition     = azurerm_postgresql_flexible_server.metals.sku_name == "B_Standard_B1ms" && azurerm_postgresql_flexible_server.metals.storage_mb == 32768 && azurerm_postgresql_flexible_server.metals.version == "16"
    error_message = "Database sizing and version must match the PowerShell demo."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server_firewall_rule.local_client.start_ip_address == var.client_ip && azurerm_postgresql_flexible_server_firewall_rule.local_client.end_ip_address == var.client_ip
    error_message = "Local firewall rule must permit only the selected client IP."
  }
  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:gdzierzon@9723466/cohort-d-dzierzong-metals-simple-deploy@1361521533:environment:Development"
    error_message = "OIDC must match the exact subject emitted by this repository."
  }
  assert {
    condition     = azurerm_role_assignment.github_deployment.scope == azurerm_linux_web_app.metals.id && azurerm_role_assignment.github_deployment.role_definition_name == "Website Contributor"
    error_message = "The GitHub identity must be scoped to deploying this Web App."
  }
  assert {
    condition     = strcontains(azurerm_linux_web_app.metals.app_settings["DB_URL"], "Test%20%40Password%2B123@")
    error_message = "Database URL must percent-encode spaces, @, and + in the password."
  }
}

run "different_demo_name" {
  command = plan
  variables {
    user_name          = "classroom"
    github_environment = "Demo:Two"
  }
  assert {
    condition     = azurerm_resource_group.metals.name == "expeditors-classroom-metals-rg" && azurerm_linux_web_app.metals.name == "expeditors-classroom-metals-api"
    error_message = "Changing user_name must keep resource names consistent."
  }
  assert {
    condition     = endswith(azurerm_federated_identity_credential.github.subject, ":environment:Demo%3ATwo")
    error_message = "Colons in environment names must be encoded for GitHub OIDC."
  }
}

run "reject_invalid_client_ip" {
  command = plan
  variables {
    client_ip = "0.0.0.0/0"
  }
  expect_failures = [var.client_ip]
}
