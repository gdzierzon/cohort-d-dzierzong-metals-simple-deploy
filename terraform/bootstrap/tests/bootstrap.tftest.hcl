mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000001"
}

run "bootstrap_survives_application_teardown" {
  command = plan

  assert {
    condition     = azurerm_resource_group.bootstrap.name == "expeditors-dzierzon-terraform-rg"
    error_message = "Bootstrap must use its own group, not the metals application group."
  }
  assert {
    condition     = endswith(azurerm_federated_identity_credential.terraform.subject, ":environment:Terraform")
    error_message = "The infrastructure identity must trust the Terraform environment."
  }
  assert {
    condition     = !azurerm_storage_account.state.shared_access_key_enabled && azurerm_storage_account.state.blob_properties[0].versioning_enabled
    error_message = "State storage must use identity authentication and retain blob versions."
  }
  assert {
    condition     = strcontains(azurerm_role_assignment.deployment_roles.condition, "@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {de139f84-1756-47ae-9be6-808fbbe84772, b24988ac-6180-42a0-ab88-20f7382dd24c}") && strcontains(azurerm_role_assignment.deployment_roles.condition, "@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {de139f84-1756-47ae-9be6-808fbbe84772, b24988ac-6180-42a0-ab88-20f7382dd24c}")
    error_message = "Both role assignment creation and deletion must be limited to Website Contributor and Contributor."
  }
}
