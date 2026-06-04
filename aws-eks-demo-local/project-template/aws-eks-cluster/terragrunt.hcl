# ─────────────────────────────────────────────────────────────────────────────
# aws-eks-cluster — EKS cluster with managed node group
# Module: terraform-aws-modules/eks/aws
# Depends on: aws-vpc
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = find_in_parent_folders("aws-provider.hcl")
}

locals {
  project_vars  = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  project_name  = local.project_vars.locals.project_name
  eks_version   = local.project_vars.locals.eks_version
  instance_type = local.project_vars.locals.eks_node_instance_type
}

dependency "vpc" {
  config_path = "../aws-vpc"

  # Mock outputs allow `terragrunt plan` to run before the VPC is applied
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.8.5"
}

inputs = {
  cluster_name    = local.project_name
  cluster_version = local.eks_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  # Core add-ons — always keep these at most_recent to receive security patches
  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  # Default managed node group — Karpenter handles dynamic scaling beyond this baseline
  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = [local.instance_type]

      labels = {
        Project = local.project_name
        Role    = "default"
      }
    }
  }

  tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
  }
}
