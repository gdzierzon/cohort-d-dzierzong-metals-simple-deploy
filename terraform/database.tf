# B_ is Terraform's prefix for the Burstable tier.
resource "azurerm_postgresql_flexible_server" "metals" {
  name                          = "${local.prefix}-pg"
  resource_group_name           = azurerm_resource_group.metals.name
  location                      = azurerm_resource_group.metals.location
  version                       = "16"
  administrator_login           = local.db_user
  administrator_password        = var.db_password
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  auto_grow_enabled             = false
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  # Omitting high_availability keeps HA disabled, as in the PowerShell script.
  tags = { Environment = "Development" }
}

resource "azurerm_postgresql_flexible_server_database" "metals" {
  name      = local.db_name
  server_id = azurerm_postgresql_flexible_server.metals.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Matches --public-access 0.0.0.0: Azure services, not all internet addresses.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.metals.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "local_client" {
  name             = "LocalClient-${replace(var.client_ip, ".", "-")}"
  server_id        = azurerm_postgresql_flexible_server.metals.id
  start_ip_address = var.client_ip
  end_ip_address   = var.client_ip
}
