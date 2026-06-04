# ─────────────────────────────────────────────────────────────────────────────
# aws-vpc — VPC with public/private subnets
# Module: terraform-aws-modules/vpc/aws
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = find_in_parent_folders("aws-provider.hcl")
}

locals {
  project_vars    = read_terragrunt_config(find_in_parent_folders("project.yaml"))
  project_name    = local.project_vars.locals.project_name
  region          = local.project_vars.locals.region
  vpc_cidr        = local.project_vars.locals.vpc_cidr
  private_subnets = local.project_vars.locals.private_subnets
  public_subnets  = local.project_vars.locals.public_subnets
}

terraform {
  # Public Terraform registry shorthand (tfr:///)
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.8.1"
}

inputs = {
  name = local.project_name
  cidr = local.vpc_cidr

  azs             = ["${local.region}a", "${local.region}b"]
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true   # cost-saving for non-prod; set false for HA in prod
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by EKS and Karpenter for subnet auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.project_name}"     = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${local.project_name}"     = "shared"
    "karpenter.sh/discovery"                          = local.project_name
  }

  tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
  }
}
