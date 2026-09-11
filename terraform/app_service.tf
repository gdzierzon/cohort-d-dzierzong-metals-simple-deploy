# Registry permissions use AcrPull with classic registry RBAC, not ABAC,
# matching az_create_resources.ps1/.sh.
resource "azurerm_container_registry" "metals" {
  name                = replace("${local.prefix}acr", "-", "")
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_resource_group.metals.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_service_plan" "metals" {
  name                = "${local.prefix}-appservice-plan"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_resource_group.metals.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# Preserved across applies via Terraform state, unlike a value computed fresh
# on every plan, so re-applying does not revoke already-issued JWTs.
resource "random_id" "jwt_secret" {
  byte_length = 48
}

resource "azurerm_linux_web_app" "api" {
  name                = "${local.prefix}-api"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_service_plan.metals.location
  service_plan_id     = azurerm_service_plan.metals.id
  https_only          = true

  # Deployment authenticates through OIDC, not a publish profile.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 2
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "metals-api:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.metals.login_server}"
    }
  }

  # Matches the filesystem log config az_create_resources.ps1/.sh set with
  # `az webapp log config --docker-container-logging filesystem`.
  logs {
    detailed_error_messages = false
    failed_request_tracing  = false

    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 100
      }
    }
  }

  app_settings = {
    WEBSITES_PORT                       = "5000"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    DB_HOST                             = azurerm_postgresql_flexible_server.metals.fqdn
    DB_PORT                             = "5432"
    DB_NAME                             = azurerm_postgresql_flexible_server_database.metals.name
    DB_USER                             = local.db_user
    DB_PASSWORD                         = var.db_password
    PGSSLMODE                           = "require"
    JWT_SECRET_KEY                      = random_id.jwt_secret.b64_std
    JWT_EXPIRATION_MINUTES              = "60"
    FLASK_DEBUG                         = "0"
  }
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.metals.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_linux_web_app" "ui" {
  name                = "${local.prefix}-ui"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_service_plan.metals.location
  service_plan_id     = azurerm_service_plan.metals.id
  https_only          = true

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 2
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "metals-ui:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.metals.login_server}"
    }
  }

  logs {
    detailed_error_messages = false
    failed_request_tracing  = false

    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 100
      }
    }
  }

  app_settings = {
    WEBSITES_PORT                       = "8080"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    # Azure's platform DNS; Docker's own 127.0.0.11 (the image default) does
    # not exist on Web Apps. See metals_ui/docker/default.conf.template.
    NGINX_RESOLVER = "168.63.129.16"
    API_UPSTREAM   = "https://${azurerm_linux_web_app.api.default_hostname}"
  }
}

resource "azurerm_role_assignment" "ui_acr_pull" {
  scope                = azurerm_container_registry.metals.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.ui.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
