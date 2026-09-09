# Backend location is supplied by the workflow or a local backend.hcl file.
# The bootstrap configuration has separate local state and is not destroyed here.
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
