# ─────────────────────────────────────────────────────────────────────────────
# k8s-providers.hcl — Kubernetes and Helm provider configuration
#
# Included by Kubernetes resource components (aws-k8s-resources/*/terragrunt.hcl):
#   include "k8s_provider" { path = find_in_parent_folders("k8s-providers.hcl") }
#
# The providers authenticate to EKS using a short-lived token obtained via
# the AWS SDK, so no static kubeconfig file is needed in CI.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  project_name = local.project_vars.locals.project_name
  region       = local.project_vars.locals.region
  aws_account  = local.project_vars.locals.aws_account_id

  role_name = "TerraformAutomationRole"
}

generate "k8s_providers" {
  path      = "k8s_providers.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
# ── AWS provider (needed to fetch EKS token) ──────────────────────────────────
provider "aws" {
  region = "${local.region}"
  assume_role {
    role_arn = "arn:aws:iam::${local.aws_account}:role/${local.role_name}"
  }
}

# ── EKS cluster data sources ──────────────────────────────────────────────────
data "aws_eks_cluster" "this" {
  name = "${local.project_name}"
}

data "aws_eks_cluster_auth" "this" {
  name = "${local.project_name}"
}

# ── Kubernetes provider ───────────────────────────────────────────────────────
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# ── Helm provider ─────────────────────────────────────────────────────────────
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
EOF
}
