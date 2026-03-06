###############################################################################
# Standard Variables
###############################################################################

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "sandbox"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, sandbox."
  }
}

variable "project" {
  description = "Project name used for resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.project))
    error_message = "Project must be 3-30 chars, lowercase alphanumeric and hyphens, start with letter, end with alphanumeric."
  }
}

variable "tags" {
  description = "Additional tags to merge with default tags on all resources."
  type        = map(string)
  default     = {}
}

###############################################################################
# IAM Roles
###############################################################################

variable "roles" {
  description = <<-EOT
    List of IAM role configurations to create.

    Each object supports:
    - name:                  Role name (required)
    - assume_role_policy:    JSON assume-role policy document (required)
    - description:           Human-readable description
    - max_session_duration:  Max session in seconds (3600-43200, default 3600)
    - permissions_boundary:  ARN of the permissions boundary policy
    - path:                  IAM path for the role (default "/")
    - force_detach_policies: Detach policies before destroying (default true)
    - managed_policy_arns:   List of managed policy ARNs to attach
    - inline_policies:       Map of inline policy name to JSON policy document
  EOT
  type = list(object({
    name                  = string
    assume_role_policy    = string
    description           = optional(string, "")
    max_session_duration  = optional(number, 3600)
    permissions_boundary  = optional(string, null)
    path                  = optional(string, "/")
    force_detach_policies = optional(bool, true)
    managed_policy_arns   = optional(list(string), [])
    inline_policies       = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.roles : can(regex("^[\\w+=,.@-]+$", r.name))
    ])
    error_message = "Role names must match IAM naming rules: alphanumeric, plus (+), equals (=), comma (,), period (.), at (@), hyphen (-)."
  }

  validation {
    condition = alltrue([
      for r in var.roles : r.max_session_duration >= 3600 && r.max_session_duration <= 43200
    ])
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

###############################################################################
# IAM Policies
###############################################################################

variable "policies" {
  description = <<-EOT
    List of IAM managed policy configurations to create.

    Each object supports:
    - name:            Policy name (required)
    - description:     Human-readable description
    - path:            IAM path for the policy (default "/")
    - policy_document: JSON policy document (required)
  EOT
  type = list(object({
    name            = string
    description     = optional(string, "")
    path            = optional(string, "/")
    policy_document = string
  }))
  default = []

  validation {
    condition = alltrue([
      for p in var.policies : can(regex("^[\\w+=,.@-]+$", p.name))
    ])
    error_message = "Policy names must match IAM naming rules."
  }
}

###############################################################################
# Instance Profiles
###############################################################################

variable "instance_profiles" {
  description = <<-EOT
    List of IAM instance profile configurations for EC2.

    Each object supports:
    - name: Instance profile name (required)
    - role: Name of the IAM role to associate (must be a role created by this module)
    - path: IAM path for the instance profile (default "/")
  EOT
  type = list(object({
    name = string
    role = string
    path = optional(string, "/")
  }))
  default = []
}

###############################################################################
# OIDC Providers
###############################################################################

variable "oidc_providers" {
  description = <<-EOT
    List of IAM OIDC provider configurations (for EKS, GitHub Actions, etc.).

    Each object supports:
    - url:             OIDC provider URL (required, must start with https://)
    - client_id_list:  List of client IDs (audiences)
    - thumbprint_list: List of server certificate thumbprints
    - tags:            Additional tags specific to this provider
  EOT
  type = list(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = list(string)
    tags            = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for o in var.oidc_providers : can(regex("^https://", o.url))
    ])
    error_message = "OIDC provider URLs must start with https://."
  }
}

###############################################################################
# Account Password Policy (Compliance)
###############################################################################

variable "password_policy" {
  description = <<-EOT
    IAM account password policy settings.
    Defaults are aligned with FedRAMP High and CIS AWS Foundations Benchmark.

    Set to null to skip password policy management entirely.
  EOT
  type = object({
    minimum_password_length        = optional(number, 14)
    require_symbols                = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    require_lowercase_characters   = optional(bool, true)
    max_password_age               = optional(number, 90)
    password_reuse_prevention      = optional(number, 24)
    allow_users_to_change_password = optional(bool, true)
    hard_expiry                    = optional(bool, false)
  })
  default = {}
}

###############################################################################
# Optional KMS Key
###############################################################################

variable "kms_key_arn" {
  description = "Optional KMS key ARN for encrypting policy documents at rest. Used in policy conditions when provided."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:(aws|aws-cn|aws-us-gov):kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN or null."
  }
}
