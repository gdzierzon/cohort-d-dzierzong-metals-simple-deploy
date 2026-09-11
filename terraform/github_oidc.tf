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

resource "azurerm_role_assignment" "github_deployment_api" {
  scope                = azurerm_linux_web_app.api.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_deployment_ui" {
  scope                = azurerm_linux_web_app.ui.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

# Lets the deployment workflow build/push images with az acr build, matching
# az_deploy.ps1/.sh. AcrPush (data-plane push/pull) and Reader (control-plane
# "registries/read") both turned out insufficient: az acr build also needs
# Microsoft.ContainerRegistry/registries/listBuildSourceUploadUrl/action and
# scheduleRun/action to orchestrate an ACR Tasks build, which only a role
# like Contributor provides. Scoped to just this registry, not the
# subscription, so the blast radius stays contained to image build/push.
resource "azurerm_role_assignment" "github_acr_contributor" {
  scope                = azurerm_container_registry.metals.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
