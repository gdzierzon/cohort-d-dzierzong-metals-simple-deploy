resource "azurerm_service_plan" "metals" {
  name                = "${local.prefix}-appservice-plan"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_resource_group.metals.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "metals" {
  name                = "${local.prefix}-api"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_service_plan.metals.location
  service_plan_id     = azurerm_service_plan.metals.id

  # Deployment authenticates through OIDC, not a publish profile.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    always_on        = false
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    DB_HOST                        = azurerm_postgresql_flexible_server.metals.fqdn
    DB_NAME                        = azurerm_postgresql_flexible_server_database.metals.name
    DB_USER                        = local.db_user
    DB_PASSWORD                    = var.db_password
    DB_URL                         = "postgresql://${local.db_user}:${replace(urlencode(var.db_password), "+", "%20")}@${azurerm_postgresql_flexible_server.metals.fqdn}:5432/${local.db_name}?sslmode=require"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    FLASK_DEBUG                    = "0"
  }
}
