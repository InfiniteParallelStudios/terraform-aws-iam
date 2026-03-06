###############################################################################
# Example Variables
###############################################################################

variable "aws_region" {
  description = "AWS region for the example deployment."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name."
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default = {
    Example = "complete"
  }
}

variable "github_org" {
  description = "GitHub organization or user for OIDC trust."
  type        = string
  default     = "my-org"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust."
  type        = string
  default     = "my-repo"
}
