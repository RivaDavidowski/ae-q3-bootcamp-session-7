# ============================================================
# Dev Stack — calls the Slalom PE Lab ECS App golden-path module
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — shared bucket, key is unique per student repo to avoid collisions.
  # The key is passed at runtime via -backend-config in CI (see golden-path-ci.yml).
  #
  # STEP 1-2 (local validation): keep this block commented out so `terraform init`
  # works without AWS credentials. Uncomment in Step 3 before running terraform apply.
  #
  # backend "s3" {
  #   bucket  = "pe-labs-terraform-state"
  #   region  = "us-east-2"
  #   encrypt = true
  #   # key is injected by CI: todo-service/<github-repo>/dev/terraform.tfstate
  # }
}

# ---------------------------------------------------------------
# Provider configuration
# ---------------------------------------------------------------
# MOCK MODE (Steps 1–2): The skip_* flags and placeholder credentials
# allow `terraform plan` to run without real AWS credentials.
# This is intentional for validating IaC structure in the bootcamp.
#
# REAL DEPLOY (Step 3): When running `terraform apply` via GitHub Actions
# with OIDC, remove the access_key, secret_key, and skip_* lines below.
# The AWS provider will pick up short-lived credentials automatically
# from the environment variables set by aws-actions/configure-aws-credentials.
# ---------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  #we are setting up OIDC as pre-requisite for this lab, so we can use mock credentials and skip validation when running terraform plan locally without real AWS creds. The real OIDC credentials will be automatically injected into the GitHub Actions runner environment, so no need to set them here in the provider config.
  # REMOVE these four lines in Step 3 when switching to real OIDC credentials:
  access_key                  = "mock-access-key"
  secret_key                  = "mock-secret-key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------
# TODO: Run `/iac-scaffold` to add the todo_service module call,
#       input variables, and stack outputs below.
# ---------------------------------------------------------------
