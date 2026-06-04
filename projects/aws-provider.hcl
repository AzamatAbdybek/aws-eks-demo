# ─────────────────────────────────────────────────────────────────────────────
# aws-provider.hcl — AWS provider configuration
#
# Included by every component's terragrunt.hcl:
#   include "provider" { path = find_in_parent_folders("aws-provider.hcl") }
#
# Role selection:
#   - CI/CD pipelines  → TerraformAutomationRole  (detected via CI_JOB_ID env var)
#   - Local developer  → TerraformAdminRole
# ─────────────────────────────────────────────────────────────────────────────

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  region       = local.project_vars.locals.region
  environment  = local.project_vars.locals.environment
  project_name = local.project_vars.locals.project_name
  aws_account  = local.project_vars.locals.aws_account_id

  # Role names — update these to match your AWS account setup
  automation_role = "TerraformAutomationRole"
  admin_role      = "TerraformAdminRole"

  # Select role based on whether we are running in CI or locally
  role_name = get_env("CI_JOB_ID", "") != "" ? local.automation_role : local.admin_role
}

generate "aws_provider" {
  path      = "aws_provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region = "${local.region}"

  assume_role {
    role_arn = "arn:aws:iam::${local.aws_account}:role/${local.role_name}"
  }

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "${local.environment}"
      Project     = "${local.project_name}"
    }
  }
}
EOF
}
