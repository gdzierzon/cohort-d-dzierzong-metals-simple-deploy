output "resource_group_name" {
  value = azurerm_resource_group.metals.name
}

output "api_webapp_name" {
  description = "Must match AZURE_WEBAPP_NAME in the GitHub Actions workflow."
  value       = azurerm_linux_web_app.api.name
}

output "api_webapp_url" {
  value = "https://${azurerm_linux_web_app.api.default_hostname}"
}

output "ui_webapp_name" {
  value = azurerm_linux_web_app.ui.name
}

output "ui_webapp_url" {
  value = "https://${azurerm_linux_web_app.ui.default_hostname}"
}

output "tutorials_webapp_name" {
  value = azurerm_linux_web_app.tutorials.name
}

output "tutorials_webapp_url" {
  description = "The hosted tutorial site."
  value       = "https://${azurerm_linux_web_app.tutorials.default_hostname}"
}

output "container_registry_login_server" {
  description = "Push metals-api/metals-ui here, e.g. with az_deploy.ps1/.sh, before apply pulls a new image_tag."
  value       = azurerm_container_registry.metals.login_server
}

output "database" {
  description = "Connection details for the schema loader; password is supplied separately."
  value = {
    host    = azurerm_postgresql_flexible_server.metals.fqdn
    port    = 5432
    user    = local.db_user
    dbname  = azurerm_postgresql_flexible_server_database.metals.name
    sslmode = "require"
  }
}

output "github_secrets" {
  description = "Copy these IDs to GitHub repository secrets. These are identifiers, not passwords."
  value = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.github.client_id
    AZURE_TENANT_ID       = azurerm_user_assigned_identity.github.tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
  }
}

output "github_federated_subject" {
  value = azurerm_federated_identity_credential.github.subject
}
