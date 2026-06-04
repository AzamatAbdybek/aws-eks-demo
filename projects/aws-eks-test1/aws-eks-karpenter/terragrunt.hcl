# ─────────────────────────────────────────────────────────────────────────────
# aws-eks-karpenter — Karpenter node auto-provisioner
# Module: terraform-aws-modules/eks/aws//modules/karpenter
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
    cluster_name              = "mock-cluster"
    cluster_endpoint          = "https://mock.eks.amazonaws.com"
    cluster_oidc_issuer_url   = "https://oidc.eks.us-east-1.amazonaws.com/id/MOCK"
    oidc_provider_arn         = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/MOCK"
  }
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//modules/karpenter?version=20.8.5"
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name

  # IRSA (IAM Roles for Service Accounts) — lets Karpenter call EC2 APIs
  irsa_oidc_provider_arn          = dependency.eks.outputs.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
  }
}
