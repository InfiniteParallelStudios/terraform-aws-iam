###############################################################################
# Local Values
###############################################################################

locals {
  # Standard naming prefix for all resources
  name_prefix = "${var.project}-${var.environment}"

  # Account and partition references for policy construction
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name

  # Default tags merged with user-supplied tags
  default_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "terraform-aws-iam"
  }

  tags = merge(local.default_tags, var.tags)

  # --------------------------------------------------------------------------
  # Role lookup maps — keyed by role name for deterministic for_each
  # --------------------------------------------------------------------------
  roles_map = { for r in var.roles : r.name => r }

  # Flatten managed policy attachments into a map keyed by "role:policy_arn"
  role_policy_attachments = merge([
    for r in var.roles : {
      for arn in r.managed_policy_arns :
      "${r.name}:${arn}" => {
        role_name  = r.name
        policy_arn = arn
      }
    }
  ]...)

  # Flatten inline policies into a map keyed by "role:policy_name"
  role_inline_policies = merge([
    for r in var.roles : {
      for policy_name, policy_doc in r.inline_policies :
      "${r.name}:${policy_name}" => {
        role_name   = r.name
        policy_name = policy_name
        policy_doc  = policy_doc
      }
    }
  ]...)

  # --------------------------------------------------------------------------
  # Policy lookup map
  # --------------------------------------------------------------------------
  policies_map = { for p in var.policies : p.name => p }

  # --------------------------------------------------------------------------
  # Instance profiles lookup map
  # --------------------------------------------------------------------------
  instance_profiles_map = { for ip in var.instance_profiles : ip.name => ip }

  # --------------------------------------------------------------------------
  # OIDC providers lookup map — keyed by URL
  # --------------------------------------------------------------------------
  oidc_providers_map = { for o in var.oidc_providers : o.url => o }
}
