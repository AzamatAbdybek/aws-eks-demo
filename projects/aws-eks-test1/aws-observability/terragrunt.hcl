# ─────────────────────────────────────────────────────────────────────────────
# aws-observability — Amazon Managed Service for Prometheus workspace
# Module: terraform-aws-modules/managed-service-prometheus/aws
# Depends on: aws-eks-cluster
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = find_in_parent_folders("aws-provider.hcl")
}

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  project_name = local.project_vars.locals.project_name
}

dependency "eks" {
  config_path = "../aws-eks-cluster"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name     = "mock-cluster"
    cluster_endpoint = "https://mock.eks.amazonaws.com"
  }
}

terraform {
  source = "tfr:///terraform-aws-modules/managed-service-prometheus/aws?version=2.2.3"
}

inputs = {
  workspace_alias = local.project_name

  # Basic alert manager — extend this for real alerting routes (PagerDuty, Slack, etc.)
  alert_manager_definition = <<-EOT
    alertmanager_config: |
      route:
        receiver: 'default'
      receivers:
        - name: 'default'
  EOT

  tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
  }
}
