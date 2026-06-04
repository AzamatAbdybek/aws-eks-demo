# aws-eks-terragrunt-gitlab

A reference implementation of a **multi-project AWS EKS platform** managed with
[Terragrunt](https://terragrunt.gruntwork.io/) and automated through GitLab CI/CD.

## Features

- **DRY infrastructure** — one project template, unlimited project instances
- **Automated EKS upgrades** — pipeline discovers new versions, runs `terragrunt plan`,
  creates a GitLab MR, and assigns reviewers automatically
- **One-click project provisioning** — trigger the pipeline with a few variables to
  spin up a complete VPC + EKS + Karpenter + Observability stack
- **Modular components** — each infrastructure layer is an independent Terragrunt
  module with explicit dependency wiring

## Repository structure

```
.
├── .gitlab-ci.yml                   # Root pipeline (stages + includes)
├── root.hcl                         # Root Terragrunt config (state backend, versions)
│
├── .gitlab/
│   ├── deploy.gitlab-ci.yml         # Change detection → dynamic job generation → trigger
│   ├── provision.gitlab-ci.yml      # Manual new-project provisioning pipeline
│   ├── eks-upgrade.gitlab-ci.yml    # Automated EKS version upgrade pipeline
│   ├── generate_jobs.py             # Generates per-project Terragrunt jobs dynamically
│   ├── jobs-templates/
│   │   └── project-template.yml     # fmt / plan / apply / outputs template
│   └── generated-includes/
│       ├── jobs.gitlab-ci.yml       # Reusable .terragrunt:* job anchors
│       ├── main.gitlab-ci.yml       # Child pipeline config (stages, image, vars)
│       └── rules.gitlab-ci.yml      # Shared pipeline rules
│
├── project-template/                # Blueprint copied when provisioning new projects
│   ├── project.yaml                 # envsubst template — rendered at provision time
│   ├── aws-vpc/
│   ├── aws-eks-cluster/
│   ├── aws-eks-karpenter/
│   ├── aws-observability/
│   └── aws-k8s-resources/
│       ├── nginx-gateway/
│       └── velero-backup/
│
└── projects/
    ├── aws-provider.hcl             # AWS provider (shared by all projects)
    ├── common-vars.hcl              # Shared variables (Helm creds, role names)
    ├── k8s-providers.hcl            # Kubernetes / Helm providers
    ├── aws-eks-test1/               # Example project — us-east-1 dev
    └── aws-eks-test2/               # Example project — eu-west-1 staging
```

## Prerequisites

| Tool        | Version  |
|-------------|----------|
| Terraform   | ~> 1.5.7 |
| Terragrunt  | ~> 0.81  |
| AWS CLI     | >= 2.x   |
| Python      | >= 3.9   |

## Quick start (local)

```bash
# 1. Configure AWS credentials
aws configure  # or export AWS_PROFILE=my-profile

# 2. Plan a single component
cd projects/aws-eks-test1/aws-eks-cluster
terragrunt plan

# 3. Plan the entire project stack
cd projects/aws-eks-test1
terragrunt run-all plan

# 4. Apply (requires manual confirmation)
terragrunt run-all apply
```

## GitLab CI/CD variables

Set these in **Settings → CI/CD → Variables** before running any pipeline:

| Variable               | Required | Description                                        |
|------------------------|----------|----------------------------------------------------|
| `CI_RUNNER_TAG`        | yes      | Tag of the GitLab runner to use                    |
| `CI_IMAGE_TERRAGRUNT`  | yes      | Docker image with Terraform + Terragrunt installed |
| `HELM_REPO_USERNAME`   | no       | Username for private Helm registry                 |
| `HELM_REPO_PASSWORD`   | no       | Password for private Helm registry                 |
| `EKS_UPGRADE_GIT_TOKEN`| for EKS  | GitLab personal access token for MR creation       |
| `MR_REVIEWERS`         | for EKS  | Comma-separated GitLab usernames for MR review     |

## Provision a new project

Trigger the pipeline manually with the variables below:

| Variable      | Example          |
|---------------|------------------|
| `PROJECT_NAME`| `aws-eks-prod1`  |
| `AWS_ACCOUNT_ID` | `123456789012` |
| `REGION`      | `us-east-1`      |
| `ENVIRONMENT` | `prod`           |
| `VPC_CIDR`    | `10.0.3.0/24`    |

The pipeline will copy `project-template/`, render `project.yaml` with your values,
and commit the new project folder to `main`.

## EKS upgrade automation

```bash
# Trigger via GitLab UI with variables:
EKS_UPGRADE=true
TARGET_PROJECT=aws-eks-test1

# Optional: pin the target version
TARGET_EKS_VERSION=1.35
```

The pipeline will:
1. **Discover** — read current version, calculate next minor, verify AWS availability
2. **Validate** — temporarily bump version, run `terragrunt plan`, revert on failure
3. **Create MR** — push branch, open MR with pre-merge checklist
4. **Notify** — assign reviewers, post summary comment

## IAM roles required

Each AWS account needs two IAM roles:

- `TerraformAutomationRole` — assumed by the GitLab runner (CI/CD)
- `TerraformAdminRole` — assumed by engineers locally

Both roles need permissions for: EC2, EKS, VPC, IAM, S3, DynamoDB, CloudWatch.
