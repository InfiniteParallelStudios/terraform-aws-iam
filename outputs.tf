###############################################################################
# Role Outputs
###############################################################################

output "role_arns" {
  description = "Map of role name to ARN for all created IAM roles."
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "role_names" {
  description = "Map of role key to the fully-qualified IAM role name."
  value       = { for k, v in aws_iam_role.this : k => v.name }
}

output "role_unique_ids" {
  description = "Map of role key to unique ID for all created IAM roles."
  value       = { for k, v in aws_iam_role.this : k => v.unique_id }
}

###############################################################################
# Policy Outputs
###############################################################################

output "policy_arns" {
  description = "Map of policy name to ARN for all created IAM managed policies."
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}

output "policy_ids" {
  description = "Map of policy name to ID for all created IAM managed policies."
  value       = { for k, v in aws_iam_policy.this : k => v.id }
}

###############################################################################
# Instance Profile Outputs
###############################################################################

output "instance_profile_arns" {
  description = "Map of instance profile name to ARN."
  value       = { for k, v in aws_iam_instance_profile.this : k => v.arn }
}

output "instance_profile_names" {
  description = "Map of instance profile key to the fully-qualified name."
  value       = { for k, v in aws_iam_instance_profile.this : k => v.name }
}

###############################################################################
# OIDC Provider Outputs
###############################################################################

output "oidc_provider_arns" {
  description = "Map of OIDC provider URL to ARN."
  value       = { for k, v in aws_iam_openid_connect_provider.this : k => v.arn }
}

###############################################################################
# Password Policy Outputs
###############################################################################

output "password_policy_expire_passwords" {
  description = "Whether the password policy enforces expiration."
  value       = var.password_policy != null ? try(aws_iam_account_password_policy.this[0].expire_passwords, null) : null
}

###############################################################################
# Reusable Policy Document Outputs
###############################################################################

output "enforce_mfa_policy_json" {
  description = "JSON policy document that enforces MFA on all actions except self-service IAM."
  value       = data.aws_iam_policy_document.enforce_mfa.json
}

output "permission_boundary_policy_json" {
  description = "JSON policy document for a least-privilege permission boundary."
  value       = data.aws_iam_policy_document.permission_boundary.json
}

###############################################################################
# Account Metadata (convenience)
###############################################################################

output "account_id" {
  description = "AWS account ID where resources are deployed."
  value       = local.account_id
}

output "partition" {
  description = "AWS partition (aws, aws-cn, aws-us-gov)."
  value       = local.partition
}
