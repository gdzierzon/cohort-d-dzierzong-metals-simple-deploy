resource "azurerm_user_assigned_identity" "github" {
  name                = "${local.prefix}-github"
  resource_group_name = azurerm_resource_group.metals.name
  location            = azurerm_resource_group.metals.location
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-development"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = local.oidc_subject
}

resource "azurerm_role_assignment" "github_deployment" {
  scope                = azurerm_linux_web_app.metals.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
