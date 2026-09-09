locals {
  prefix       = "expeditors-${var.user_name}-metals"
  db_user      = "metalsadmin"
  db_name      = "metals"
  oidc_subject = coalesce(var.github_federated_subject, "repo:${var.github_subject_repository}:environment:${replace(var.github_environment, ":", "%3A")}")
}

resource "azurerm_resource_group" "metals" {
  name     = "${local.prefix}-rg"
  location = var.location
}
