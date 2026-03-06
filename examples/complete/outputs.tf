###############################################################################
# Example Outputs
###############################################################################

output "role_arns" {
  description = "ARNs of all created IAM roles."
  value       = module.iam.role_arns
}

output "role_names" {
  description = "Names of all created IAM roles."
  value       = module.iam.role_names
}

output "policy_arns" {
  description = "ARNs of all created IAM policies."
  value       = module.iam.policy_arns
}

output "instance_profile_arns" {
  description = "ARNs of all created instance profiles."
  value       = module.iam.instance_profile_arns
}

output "oidc_provider_arns" {
  description = "ARNs of all created OIDC providers."
  value       = module.iam.oidc_provider_arns
}

output "enforce_mfa_policy_json" {
  description = "MFA enforcement policy document (JSON)."
  value       = module.iam.enforce_mfa_policy_json
}

output "permission_boundary_policy_json" {
  description = "Permission boundary policy document (JSON)."
  value       = module.iam.permission_boundary_policy_json
}

output "password_policy_expire_passwords" {
  description = "Whether password expiry is enforced."
  value       = module.iam.password_policy_expire_passwords
}
