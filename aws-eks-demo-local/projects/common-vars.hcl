# ─────────────────────────────────────────────────────────────────────────────
# common-vars.hcl — Variables shared across all projects
#
# Values here are injected at runtime via GitLab CI/CD environment variables.
# For local development, export these variables in your shell before running
# terragrunt commands.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Helm chart registry credentials
  # Required only if you use a private Helm registry for custom charts.
  helm_repo_url      = get_env("HELM_REPO_URL", "https://charts.example.com")
  helm_repo_username = get_env("HELM_REPO_USERNAME", "")
  helm_repo_password = get_env("HELM_REPO_PASSWORD", "")

  # IAM role names used for Terraform operations
  ci_role_name    = "TerraformAutomationRole"  # assumed by GitLab runners
  local_role_name = "TerraformAdminRole"        # assumed by developers locally
}
