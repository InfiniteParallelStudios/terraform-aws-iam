###############################################################################
# Terraform Tests — terraform-aws-iam
#
# Run with: terraform test
# Requires: TF >= 1.7, AWS credentials with IAM permissions
###############################################################################

# -----------------------------------------------------------------------------
# Global variables for all test runs
# -----------------------------------------------------------------------------

variables {
  project     = "tftest"
  environment = "dev"
  tags = {
    TestSuite = "terraform-aws-iam"
  }
}

# =============================================================================
# Test: Password Policy — FedRAMP High Compliance Defaults
# =============================================================================

run "password_policy_compliance_defaults" {
  command = plan

  variables {
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
  }

  # Verify the password policy resource is planned
  assert {
    condition     = length(aws_iam_account_password_policy.this) == 1
    error_message = "Password policy resource must be created when password_policy is set."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].minimum_password_length == 14
    error_message = "Minimum password length must be 14 for FedRAMP High compliance."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].require_symbols == true
    error_message = "Symbols must be required for compliance."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].require_numbers == true
    error_message = "Numbers must be required for compliance."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].require_uppercase_characters == true
    error_message = "Uppercase characters must be required for compliance."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].require_lowercase_characters == true
    error_message = "Lowercase characters must be required for compliance."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].max_password_age == 90
    error_message = "Max password age must be 90 days for FedRAMP High."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].password_reuse_prevention == 24
    error_message = "Password reuse prevention must be 24 for FedRAMP High."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].allow_users_to_change_password == true
    error_message = "Users must be allowed to change their own passwords."
  }
}

# =============================================================================
# Test: Password Policy — Skip When Null
# =============================================================================

run "password_policy_skip_when_null" {
  command = plan

  variables {
    password_policy = null
  }

  assert {
    condition     = length(aws_iam_account_password_policy.this) == 0
    error_message = "Password policy must not be created when set to null."
  }
}

# =============================================================================
# Test: Role Creation With Tags
# =============================================================================

run "role_creation_with_tags" {
  command = plan

  variables {
    password_policy = null
    roles = [
      {
        name = "test-role"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "ec2.amazonaws.com" }
          }]
        })
        description          = "Test role for unit tests"
        max_session_duration = 7200
        path                 = "/test/"
      },
    ]
  }

  # Role is planned
  assert {
    condition     = length(aws_iam_role.this) == 1
    error_message = "Exactly one IAM role must be created."
  }

  # Name prefix is applied
  assert {
    condition     = aws_iam_role.this["test-role"].name == "tftest-dev-test-role"
    error_message = "Role name must include project-environment prefix."
  }

  # Path is set
  assert {
    condition     = aws_iam_role.this["test-role"].path == "/test/"
    error_message = "Role path must be set to /test/."
  }

  # Max session duration is set
  assert {
    condition     = aws_iam_role.this["test-role"].max_session_duration == 7200
    error_message = "Max session duration must be 7200."
  }

  # Standard tags are present
  assert {
    condition     = aws_iam_role.this["test-role"].tags["Project"] == "tftest"
    error_message = "Role must have Project tag set to 'tftest'."
  }

  assert {
    condition     = aws_iam_role.this["test-role"].tags["Environment"] == "dev"
    error_message = "Role must have Environment tag set to 'dev'."
  }

  assert {
    condition     = aws_iam_role.this["test-role"].tags["ManagedBy"] == "terraform"
    error_message = "Role must have ManagedBy tag set to 'terraform'."
  }

  assert {
    condition     = aws_iam_role.this["test-role"].tags["Module"] == "terraform-aws-iam"
    error_message = "Role must have Module tag set to 'terraform-aws-iam'."
  }

  # User-supplied tags are merged
  assert {
    condition     = aws_iam_role.this["test-role"].tags["TestSuite"] == "terraform-aws-iam"
    error_message = "User-supplied tags must be merged into role tags."
  }
}

# =============================================================================
# Test: Policy Creation
# =============================================================================

run "policy_creation" {
  command = plan

  variables {
    password_policy = null
    policies = [
      {
        name        = "test-policy"
        description = "Test policy for unit tests"
        path        = "/test/"
        policy_document = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = ["s3:GetObject"]
            Resource = "*"
          }]
        })
      },
    ]
  }

  assert {
    condition     = length(aws_iam_policy.this) == 1
    error_message = "Exactly one IAM policy must be created."
  }

  assert {
    condition     = aws_iam_policy.this["test-policy"].name == "tftest-dev-test-policy"
    error_message = "Policy name must include project-environment prefix."
  }

  assert {
    condition     = aws_iam_policy.this["test-policy"].path == "/test/"
    error_message = "Policy path must be set to /test/."
  }

  assert {
    condition     = aws_iam_policy.this["test-policy"].tags["Project"] == "tftest"
    error_message = "Policy must have Project tag."
  }
}

# =============================================================================
# Test: Instance Profile Linked to Role
# =============================================================================

run "instance_profile_creation" {
  command = plan

  variables {
    password_policy = null
    roles = [
      {
        name = "ec2-role"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "ec2.amazonaws.com" }
          }]
        })
      },
    ]
    instance_profiles = [
      {
        name = "ec2-profile"
        role = "ec2-role"
        path = "/compute/"
      },
    ]
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Exactly one instance profile must be created."
  }

  assert {
    condition     = aws_iam_instance_profile.this["ec2-profile"].name == "tftest-dev-ec2-profile"
    error_message = "Instance profile name must include project-environment prefix."
  }

  assert {
    condition     = aws_iam_instance_profile.this["ec2-profile"].path == "/compute/"
    error_message = "Instance profile path must be set to /compute/."
  }
}

# =============================================================================
# Test: OIDC Provider Creation
# =============================================================================

run "oidc_provider_creation" {
  command = plan

  variables {
    password_policy = null
    oidc_providers = [
      {
        url             = "https://token.actions.githubusercontent.com"
        client_id_list  = ["sts.amazonaws.com"]
        thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
        tags = {
          Provider = "github-actions"
        }
      },
    ]
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.this) == 1
    error_message = "Exactly one OIDC provider must be created."
  }

  # Verify provider-specific tag is merged
  assert {
    condition     = aws_iam_openid_connect_provider.this["https://token.actions.githubusercontent.com"].tags["Provider"] == "github-actions"
    error_message = "OIDC provider must include provider-specific tags."
  }

  # Verify standard tags are present
  assert {
    condition     = aws_iam_openid_connect_provider.this["https://token.actions.githubusercontent.com"].tags["ManagedBy"] == "terraform"
    error_message = "OIDC provider must include standard ManagedBy tag."
  }
}

# =============================================================================
# Test: Multiple Roles With Policy Attachments
# =============================================================================

run "multiple_roles_with_attachments" {
  command = plan

  variables {
    password_policy = null
    roles = [
      {
        name = "role-alpha"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "lambda.amazonaws.com" }
          }]
        })
        description = "Lambda execution role"
        managed_policy_arns = [
          "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        ]
      },
      {
        name = "role-beta"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "ecs-tasks.amazonaws.com" }
          }]
        })
        description = "ECS task execution role"
      },
    ]
  }

  assert {
    condition     = length(aws_iam_role.this) == 2
    error_message = "Two IAM roles must be created."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 1
    error_message = "One managed policy attachment must be created."
  }
}

# =============================================================================
# Test: Empty Module — No Resources When No Inputs
# =============================================================================

run "empty_module_no_resources" {
  command = plan

  variables {
    password_policy = null
  }

  assert {
    condition     = length(aws_iam_role.this) == 0
    error_message = "No roles should be created with empty input."
  }

  assert {
    condition     = length(aws_iam_policy.this) == 0
    error_message = "No policies should be created with empty input."
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "No instance profiles should be created with empty input."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.this) == 0
    error_message = "No OIDC providers should be created with empty input."
  }
}

# =============================================================================
# Test: MFA Enforcement Policy Document Output
# =============================================================================

run "mfa_enforcement_policy_output" {
  command = plan

  variables {
    password_policy = null
  }

  assert {
    condition     = output.enforce_mfa_policy_json != ""
    error_message = "MFA enforcement policy JSON must not be empty."
  }
}

# =============================================================================
# Test: Role Name Validation
# =============================================================================

run "tag_propagation" {
  command = plan

  variables {
    password_policy = null
    tags = {
      CostCenter = "engineering"
      Compliance = "fedramp-high"
      TestSuite  = "terraform-aws-iam"
    }
    roles = [
      {
        name = "tagged-role"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "ec2.amazonaws.com" }
          }]
        })
      },
    ]
  }

  assert {
    condition     = aws_iam_role.this["tagged-role"].tags["CostCenter"] == "engineering"
    error_message = "Custom tags must propagate to roles."
  }

  assert {
    condition     = aws_iam_role.this["tagged-role"].tags["Compliance"] == "fedramp-high"
    error_message = "Compliance tag must propagate to roles."
  }
}
