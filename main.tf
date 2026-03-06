###############################################################################
# IAM Roles
###############################################################################

resource "aws_iam_role" "this" {
  for_each = local.roles_map

  name                  = "${local.name_prefix}-${each.value.name}"
  assume_role_policy    = each.value.assume_role_policy
  description           = each.value.description
  max_session_duration  = each.value.max_session_duration
  permissions_boundary  = each.value.permissions_boundary
  path                  = each.value.path
  force_detach_policies = each.value.force_detach_policies

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${each.value.name}"
    Role = each.value.name
  })
}

###############################################################################
# IAM Role — Managed Policy Attachments
###############################################################################

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

###############################################################################
# IAM Role — Inline Policies
###############################################################################

resource "aws_iam_role_policy" "this" {
  for_each = local.role_inline_policies

  name   = each.value.policy_name
  role   = aws_iam_role.this[each.value.role_name].id
  policy = each.value.policy_doc
}

###############################################################################
# IAM Managed Policies
###############################################################################

resource "aws_iam_policy" "this" {
  for_each = local.policies_map

  name        = "${local.name_prefix}-${each.value.name}"
  description = each.value.description
  path        = each.value.path
  policy      = each.value.policy_document

  tags = merge(local.tags, {
    Name   = "${local.name_prefix}-${each.value.name}"
    Policy = each.value.name
  })
}

###############################################################################
# IAM Instance Profiles
###############################################################################

resource "aws_iam_instance_profile" "this" {
  for_each = local.instance_profiles_map

  name = "${local.name_prefix}-${each.value.name}"
  role = aws_iam_role.this[each.value.role].name
  path = each.value.path

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${each.value.name}"
  })
}

###############################################################################
# IAM OIDC Providers
###############################################################################

resource "aws_iam_openid_connect_provider" "this" {
  for_each = local.oidc_providers_map

  url             = each.value.url
  client_id_list  = each.value.client_id_list
  thumbprint_list = each.value.thumbprint_list

  tags = merge(local.tags, each.value.tags, {
    Name = "${local.name_prefix}-oidc-${replace(replace(each.value.url, "https://", ""), "/", "-")}"
  })
}

###############################################################################
# IAM Account Password Policy (FedRAMP High + CIS Compliance)
###############################################################################

resource "aws_iam_account_password_policy" "this" {
  count = var.password_policy != null ? 1 : 0

  minimum_password_length        = var.password_policy.minimum_password_length
  require_symbols                = var.password_policy.require_symbols
  require_numbers                = var.password_policy.require_numbers
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  max_password_age               = var.password_policy.max_password_age
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  hard_expiry                    = var.password_policy.hard_expiry
}

###############################################################################
# Policy Document — Enforce MFA Condition (reusable data source)
#
# Consumers can reference: data.aws_iam_policy_document.enforce_mfa
# This policy denies all actions except IAM self-service when MFA is absent.
###############################################################################

data "aws_iam_policy_document" "enforce_mfa" {
  # Allow self-service MFA management without MFA (bootstrap)
  statement {
    sid    = "AllowSelfServiceMFA"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:GetMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:mfa/$${aws:username}",
      "arn:${local.partition}:iam::${local.account_id}:user/$${aws:username}",
    ]
  }

  # Allow users to list their own MFA devices
  statement {
    sid    = "AllowListMFA"
    effect = "Allow"
    actions = [
      "iam:ListVirtualMFADevices",
      "iam:ListUsers",
    ]
    resources = ["*"]
  }

  # Deny everything else when MFA is not present
  statement {
    sid    = "DenyAllWithoutMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:GetMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice",
      "iam:ListVirtualMFADevices",
      "iam:ListUsers",
      "iam:ChangePassword",
      "iam:GetUser",
      "sts:GetSessionToken",
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

###############################################################################
# Policy Document — Permission Boundary (least-privilege ceiling)
#
# Prevents privilege escalation; limits to the current partition/account.
# Consumers can reference: data.aws_iam_policy_document.permission_boundary
###############################################################################

data "aws_iam_policy_document" "permission_boundary" {
  # Allow all actions within the account boundary
  statement {
    sid       = "AllowWithinAccount"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [local.region]
    }
  }

  # Deny IAM privilege escalation
  statement {
    sid    = "DenyPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:CreatePolicy",
      "iam:AttachUserPolicy",
      "iam:AttachRolePolicy",
      "iam:PutUserPolicy",
      "iam:PutRolePolicy",
      "iam:AddUserToGroup",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalTag/PrivilegeEscalationAllowed"
      values   = ["true"]
    }
  }

  # Deny removal of CloudTrail (compliance guardrail)
  statement {
    sid    = "DenyCloudTrailDisruption"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
    ]
    resources = ["*"]
  }

  # Deny removal of GuardDuty (compliance guardrail)
  statement {
    sid    = "DenyGuardDutyDisruption"
    effect = "Deny"
    actions = [
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:DeleteMembers",
    ]
    resources = ["*"]
  }

  # Enforce KMS usage when a KMS key ARN is provided
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "EnforceKMSUsage"
      effect = "Deny"
      actions = [
        "s3:PutObject",
      ]
      resources = ["*"]

      condition {
        test     = "StringNotEqualsIfExists"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [var.kms_key_arn]
      }
    }
  }
}
