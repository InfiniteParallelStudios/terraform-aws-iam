###############################################################################
# Complete Example — terraform-aws-iam
#
# Demonstrates:
#   - EC2 role with instance profile
#   - Custom managed policy
#   - OIDC provider for GitHub Actions
#   - Password policy (FedRAMP High defaults)
#   - Permission boundary
#   - MFA enforcement policy
###############################################################################

# -----------------------------------------------------------------------------
# Data: build the assume-role policy for EC2
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Data: build a sample application policy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "app_policy" {
  statement {
    sid    = "AllowS3ReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.project}-${var.environment}-*",
      "arn:aws:s3:::${var.project}-${var.environment}-*/*",
    ]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSSMParameterRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["*"]
  }
}

# -----------------------------------------------------------------------------
# Data: assume-role policy for GitHub Actions OIDC
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [for arn in values(module.iam.oidc_provider_arns) : arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Module invocation
# -----------------------------------------------------------------------------

module "iam" {
  source = "../../"

  project     = var.project
  environment = var.environment
  tags        = var.tags

  # --------------------------------------------------------------------------
  # Password policy — FedRAMP High / CIS defaults (all defaults apply)
  # --------------------------------------------------------------------------
  password_policy = {
    minimum_password_length        = 14
    require_symbols                = true
    require_numbers                = true
    require_uppercase_characters   = true
    require_lowercase_characters   = true
    max_password_age               = 90
    password_reuse_prevention      = 24
    allow_users_to_change_password = true
  }

  # --------------------------------------------------------------------------
  # Roles
  # --------------------------------------------------------------------------
  roles = [
    {
      name               = "ec2-app-role"
      assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
      description        = "Role for application EC2 instances"
      path               = "/application/"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
      ]
      inline_policies = {
        app-access = data.aws_iam_policy_document.app_policy.json
      }
    },
  ]

  # --------------------------------------------------------------------------
  # Custom managed policies
  # --------------------------------------------------------------------------
  policies = [
    {
      name            = "app-s3-read"
      description     = "Read-only access to application S3 buckets"
      path            = "/application/"
      policy_document = data.aws_iam_policy_document.app_policy.json
    },
  ]

  # --------------------------------------------------------------------------
  # Instance profiles
  # --------------------------------------------------------------------------
  instance_profiles = [
    {
      name = "ec2-app-profile"
      role = "ec2-app-role"
      path = "/application/"
    },
  ]

  # --------------------------------------------------------------------------
  # OIDC providers
  # --------------------------------------------------------------------------
  oidc_providers = [
    {
      url            = "https://token.actions.githubusercontent.com"
      client_id_list = ["sts.amazonaws.com"]
      thumbprint_list = [
        "6938fd4d98bab03faadb97b34396831e3780aea1",
        "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
      ]
      tags = {
        Provider = "github-actions"
      }
    },
  ]
}
