# terraform-aws-iam

Production-grade Terraform module for AWS Identity and Access Management (IAM) resources with dual compliance defaults for **FedRAMP High** and **SOC2/CIS AWS Foundations Benchmark**.

## Features

- **IAM Roles** with assume-role policies, path-based organization, and permission boundary support
- **IAM Managed Policies** with configurable paths and descriptions
- **IAM Role Policy Attachments** for both managed and inline policies
- **IAM Instance Profiles** for EC2 workloads
- **IAM OIDC Providers** for federated identity (EKS, GitHub Actions, etc.)
- **Account Password Policy** with FedRAMP High / CIS-compliant defaults
- **MFA Enforcement Policy** (reusable policy document output)
- **Permission Boundary Policy** (reusable policy document output with privilege escalation guardrails)
- **KMS integration** for policy encryption conditions

## Design Principles

| Principle | Detail |
|-----------|--------|
| Pure resource isolation | Only IAM resources; no VPC, no compute, no storage |
| No local-exec | No shell commands, no local file paths |
| No hardcoded secrets | All sensitive values passed via variables |
| Dual compliance | FedRAMP High + SOC2/CIS defaults out of the box |
| Deterministic | Uses `for_each` with stable keys; no `count` index shifting |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7 |
| aws | >= 5.40 |

## Usage

### Minimal

```hcl
module "iam" {
  source = "path/to/terraform-aws-iam"

  project     = "myapp"
  environment = "prod"

  # Password policy with FedRAMP High defaults
  password_policy = {}
}
```

### Full Example

```hcl
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

data "aws_iam_policy_document" "app_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
  }
}

module "iam" {
  source = "path/to/terraform-aws-iam"

  project     = "myapp"
  environment = "prod"

  password_policy = {
    minimum_password_length   = 14
    require_symbols           = true
    require_numbers           = true
    require_uppercase_characters = true
    require_lowercase_characters = true
    max_password_age          = 90
    password_reuse_prevention = 24
  }

  roles = [
    {
      name               = "app-server"
      assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
      description        = "Application server role"
      path               = "/application/"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
      inline_policies = {
        app-access = data.aws_iam_policy_document.app_policy.json
      }
    },
  ]

  policies = [
    {
      name            = "app-s3-read"
      description     = "S3 read-only for app buckets"
      path            = "/application/"
      policy_document = data.aws_iam_policy_document.app_policy.json
    },
  ]

  instance_profiles = [
    {
      name = "app-server"
      role = "app-server"
      path = "/application/"
    },
  ]

  oidc_providers = [
    {
      url             = "https://token.actions.githubusercontent.com"
      client_id_list  = ["sts.amazonaws.com"]
      thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
    },
  ]
}
```

## Terragrunt Usage

This module integrates into a Terragrunt-based AWS Organization layout. IAM is a foundational
module with no dependencies -- it is deployed in every account and provides role ARNs, policy
ARNs, and instance profile names consumed by downstream modules.

### Example `terragrunt.hcl`

```hcl
# infrastructure-live/production/global/iam/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/terraform-aws-iam"
}

inputs = {
  project     = local.project
  environment = local.env

  password_policy = {
    minimum_password_length      = 14
    require_symbols              = true
    require_numbers              = true
    require_uppercase_characters = true
    require_lowercase_characters = true
    max_password_age             = 90
    password_reuse_prevention    = 24
  }

  roles = [
    {
      name               = "ec2-app-server"
      assume_role_policy = templatefile("${get_terragrunt_dir()}/policies/ec2-assume-role.json", {})
      description        = "EC2 application server role"
      path               = "/application/"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
      inline_policies = {}
    },
  ]

  instance_profiles = [
    {
      name = "ec2-app-server"
      role = "ec2-app-server"
      path = "/application/"
    },
  ]
}
```

### Folder Placement

IAM resources are global (not region-scoped), so they go in a `global/` folder:

```
infrastructure-live/
  production/
    global/
      iam/terragrunt.hcl           # roles, policies, instance profiles, OIDC
    us-east-1/
      kms/terragrunt.hcl
      s3-data/terragrunt.hcl
  staging/
    global/
      iam/terragrunt.hcl
    us-east-1/
      ...
```

### Dependencies

IAM is a foundational module with **no upstream dependencies**. It is consumed by:

| Consumer Module | Input | IAM Output Used |
|----------------|-------|-----------------|
| `terraform-aws-ec2` | `iam_instance_profile_name` | `instance_profile_names["ec2-app-server"]` |
| `terraform-aws-eks` | `cluster_role_arn` | `role_arns["eks-cluster"]` |
| `terraform-aws-lambda` | `execution_role_arn` | `role_arns["lambda-exec"]` |
| `terraform-aws-ecs` | `task_execution_role_arn` | `role_arns["ecs-task-exec"]` |

## Compliance Notes

### FedRAMP High

The following controls are addressed by this module:

| Control | Implementation |
|---------|---------------|
| AC-2 | Roles with least-privilege policies, path-based organization |
| AC-7 | Password policy with lockout-adjacent settings (hard_expiry) |
| IA-5 | 14-char minimum, complexity requirements, 90-day rotation, 24-generation reuse prevention |
| AC-6 | Permission boundaries, MFA enforcement policy |
| AU-2 | CloudTrail disruption denied in permission boundary |

### SOC2 / CIS AWS Foundations Benchmark

| CIS Control | Implementation |
|-------------|---------------|
| 1.5 | Password policy requires uppercase |
| 1.6 | Password policy requires lowercase |
| 1.7 | Password policy requires symbols |
| 1.8 | Password policy requires numbers |
| 1.9 | Password minimum length >= 14 |
| 1.10 | Password reuse prevention = 24 |
| 1.11 | Password max age = 90 days |
| 1.14 | MFA enforcement policy provided as output |

### MFA Enforcement

The module outputs a reusable MFA enforcement policy document (`enforce_mfa_policy_json`) that:

1. Allows IAM self-service MFA management without MFA (so users can bootstrap)
2. Denies all other actions when MFA is not present
3. Can be attached to any IAM user or group

### Permission Boundary

The module outputs a permission boundary policy document (`permission_boundary_policy_json`) that:

1. Restricts actions to the current AWS region
2. Denies IAM privilege escalation (unless explicitly tagged)
3. Prevents CloudTrail and GuardDuty disruption
4. Optionally enforces KMS key usage for S3 uploads

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Project name for naming and tagging | `string` | n/a | yes |
| environment | Deployment environment | `string` | n/a | yes |
| tags | Additional tags to merge | `map(string)` | `{}` | no |
| roles | List of IAM role configurations | `list(object)` | `[]` | no |
| policies | List of IAM managed policy configurations | `list(object)` | `[]` | no |
| instance_profiles | List of instance profile configurations | `list(object)` | `[]` | no |
| oidc_providers | List of OIDC provider configurations | `list(object)` | `[]` | no |
| password_policy | Account password policy settings (null to skip) | `object` | `{}` | no |
| kms_key_arn | Optional KMS key ARN for policy encryption | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arns | Map of role name to ARN |
| role_names | Map of role key to fully-qualified IAM role name |
| role_unique_ids | Map of role key to unique ID |
| policy_arns | Map of policy name to ARN |
| policy_ids | Map of policy name to ID |
| instance_profile_arns | Map of instance profile name to ARN |
| instance_profile_names | Map of instance profile key to name |
| oidc_provider_arns | Map of OIDC provider URL to ARN |
| password_policy_expire_passwords | Whether password expiry is enforced |
| enforce_mfa_policy_json | JSON policy document enforcing MFA |
| permission_boundary_policy_json | JSON policy document for permission boundary |
| account_id | AWS account ID |
| partition | AWS partition |

## Testing

Tests use the native Terraform test framework (TF >= 1.7):

```bash
cd modules/terraform-aws-iam
terraform init
terraform test
```

Test coverage includes:

- Password policy compliance validation (FedRAMP High defaults)
- Password policy skip when set to null
- Role creation with proper naming and tags
- Policy creation with path organization
- Instance profile linked to role
- OIDC provider creation with merged tags
- Multiple roles with managed policy attachments
- Empty module produces no resources
- MFA enforcement policy document is non-empty
- Tag propagation from user-supplied tags

## Examples

- [Complete](./examples/complete/) - Full deployment with roles, policies, instance profiles, and OIDC providers

## License

Apache 2.0 - See [LICENSE](./LICENSE) for details.
