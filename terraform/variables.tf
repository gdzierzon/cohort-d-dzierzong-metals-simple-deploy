variable "subscription_id" {
  description = "Azure subscription to use; authenticate locally with az login."
  type        = string
}

variable "user_name" {
  description = "Name segment shared by the original PowerShell scripts."
  type        = string
  default     = "dzierzon"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,24}$", var.user_name))
    error_message = "Use 1–25 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Azure region used by the original resource script."
  type        = string
  default     = "westus2"
}

variable "db_password" {
  description = "PostgreSQL administrator password. Supply using TF_VAR_db_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "Use a password between 8 and 128 characters that meets Azure PostgreSQL password requirements."
  }
}

variable "client_ip" {
  description = "Your public IPv4 address, allowed to initialize the database."
  type        = string

  validation {
    condition     = can(cidrnetmask("${var.client_ip}/32")) && var.client_ip != "0.0.0.0"
    error_message = "Supply one nonzero IPv4 address, without a CIDR suffix."
  }
}

variable "github_environment" {
  description = "Must match the environment selected by the deployment workflow."
  type        = string
  default     = "Development"
}

variable "github_subject_repository" {
  description = "Repository portion of the exact GitHub OIDC subject, including immutable IDs when present."
  type        = string
  default     = "gdzierzon@9723466/cohort-d-dzierzong-metals-simple-deploy@1361521533"
}

variable "github_federated_subject" {
  description = "Optional full subject override for repositories with a custom OIDC format."
  type        = string
  default     = null
}
