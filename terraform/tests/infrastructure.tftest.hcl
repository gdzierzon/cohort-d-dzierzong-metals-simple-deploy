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
  mock_resource "azurerm_container_registry" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test/providers/Microsoft.ContainerRegistry/registries/test-acr"
      login_server = "testacr.azurecr.io"
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
    condition     = azurerm_role_assignment.github_deployment_api.scope == azurerm_linux_web_app.api.id && azurerm_role_assignment.github_deployment_api.role_definition_name == "Website Contributor"
    error_message = "The GitHub identity must be scoped to deploying the API Web App."
  }
  assert {
    condition     = azurerm_role_assignment.github_deployment_ui.scope == azurerm_linux_web_app.ui.id && azurerm_role_assignment.github_deployment_ui.role_definition_name == "Website Contributor"
    error_message = "The GitHub identity must be scoped to deploying the UI Web App."
  }
  assert {
    condition     = azurerm_role_assignment.github_acr_contributor.scope == azurerm_container_registry.metals.id && azurerm_role_assignment.github_acr_contributor.role_definition_name == "Contributor"
    error_message = "The GitHub identity must be able to build/push images and orchestrate ACR Tasks builds, scoped to just the registry."
  }
  assert {
    condition     = azurerm_linux_web_app.api.app_settings["DB_PASSWORD"] == "Test @Password+123"
    error_message = "The API app must receive the raw database password, not a connection string."
  }
  assert {
    condition     = azurerm_linux_web_app.api.site_config[0].application_stack[0].docker_image_name == "metals-api:latest" && azurerm_linux_web_app.api.app_settings["WEBSITES_PORT"] == "5000"
    error_message = "The API app must run the metals-api container on port 5000."
  }
  assert {
    condition     = azurerm_linux_web_app.ui.site_config[0].application_stack[0].docker_image_name == "metals-ui:latest" && azurerm_linux_web_app.ui.app_settings["WEBSITES_PORT"] == "8080"
    error_message = "The UI app must run the metals-ui container on port 8080."
  }
  assert {
    condition     = azurerm_linux_web_app.ui.app_settings["API_UPSTREAM"] == "https://${azurerm_linux_web_app.api.default_hostname}"
    error_message = "The UI app must proxy to the API app's actual hostname."
  }
  assert {
    condition     = azurerm_linux_web_app.tutorials.site_config[0].application_stack[0].docker_image_name == "metals-tutorials:latest" && azurerm_linux_web_app.tutorials.app_settings["WEBSITES_PORT"] == "8080"
    error_message = "The tutorials app must run the metals-tutorials container on port 8080."
  }
  assert {
    condition     = azurerm_linux_web_app.tutorials.service_plan_id == azurerm_service_plan.metals.id
    error_message = "The tutorials app must share the one App Service plan rather than adding cost."
  }
  assert {
    condition     = azurerm_role_assignment.github_deployment_tutorials.scope == azurerm_linux_web_app.tutorials.id && azurerm_role_assignment.github_deployment_tutorials.role_definition_name == "Website Contributor"
    error_message = "The GitHub identity must be scoped to deploying the tutorials Web App."
  }
  assert {
    condition     = azurerm_role_assignment.api_acr_pull.scope == azurerm_container_registry.metals.id && azurerm_role_assignment.api_acr_pull.role_definition_name == "AcrPull" && azurerm_role_assignment.ui_acr_pull.scope == azurerm_container_registry.metals.id && azurerm_role_assignment.ui_acr_pull.role_definition_name == "AcrPull"
    error_message = "Each Web App's own managed identity must be granted AcrPull on the registry."
  }
}

run "different_demo_name" {
  command = plan
  variables {
    user_name          = "classroom"
    github_environment = "Demo:Two"
  }
  assert {
    condition     = azurerm_resource_group.metals.name == "expeditors-classroom-metals-rg" && azurerm_linux_web_app.api.name == "expeditors-classroom-metals-api" && azurerm_linux_web_app.ui.name == "expeditors-classroom-metals-ui" && azurerm_linux_web_app.tutorials.name == "expeditors-classroom-metals-tutorials"
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
