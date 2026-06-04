# ─────────────────────────────────────────────────────────────────────────────
# Root Terragrunt configuration
# Inherited by all child terragrunt.hcl files via find_in_parent_folders()
# ─────────────────────────────────────────────────────────────────────────────

terraform_version_constraint  = "~> 1.5.7"
terragrunt_version_constraint = "~> v0.81.0"

# ---------------------------------------------------------------------------
# S3 Remote State Backend
# Replace bucket/table names with your own before first use.
# Terragrunt will auto-create the bucket and DynamoDB table on first init.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "my-org-terraform-state"       # <-- replace with your bucket name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "my-org-terraform-state-lock"  # <-- replace with your DynamoDB table name
  }
}

# ---------------------------------------------------------------------------
# Provider plugin cache — speeds up repeated inits
# ---------------------------------------------------------------------------
terraform {
  extra_arguments "provider_cache" {
    commands = get_terraform_commands_that_need_vars()
    env_vars = {
      TF_PLUGIN_CACHE_DIR = "${get_home_path()}/.terraform.d/plugin-cache"
    }
  }
}
