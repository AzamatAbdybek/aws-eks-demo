# ─────────────────────────────────────────────────────────────────────────────
# aws-k8s-resources/velero-backup — Velero cluster backup (via EKS Blueprints)
# Module: aws-ia/eks-blueprints-addons/aws
# Depends on: aws-eks-cluster
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path = find_in_parent_folders()
}

include "k8s_provider" {
  path = find_in_parent_folders("k8s-providers.hcl")
}

locals {
  project_vars   = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  project_name   = local.project_vars.locals.project_name
  aws_account_id = local.project_vars.locals.aws_account_id
}

dependency "eks" {
  config_path = "../../aws-eks-cluster"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name      = "mock-cluster"
    cluster_endpoint  = "https://mock.eks.amazonaws.com"
    cluster_version   = "1.30"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/MOCK"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
  }
}

terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.16.3"
}

inputs = {
  cluster_name      = dependency.eks.outputs.cluster_name
  cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
  cluster_version   = dependency.eks.outputs.cluster_version
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

  enable_velero = true

  velero = {
    namespace = "velero"
    s3_backup_location_bucket = "${local.project_name}-velero-backups-${local.aws_account_id}"
    values = [
      <<-EOT
      configuration:
        backupStorageLocation:
          - name: default
            provider: aws
            bucket: ${local.project_name}-velero-backups-${local.aws_account_id}
            config:
              region: us-east-1
      schedules:
        daily-backup:
          schedule: "0 2 * * *"   # 02:00 UTC every day
          template:
            ttl: "720h"           # keep 30 days
      EOT
    ]
  }

  tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
  }
}
