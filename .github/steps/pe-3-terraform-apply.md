# Step 3 — Prepare Terraform for Real Deployment with OIDC

> [!IMPORTANT]
> **Before starting:** Make sure you're on `feat/pe-golden-path` (`git checkout feat/pe-golden-path && git pull`). Your IaC and CI work from Steps 1 and 2 are already on this branch.

> [!NOTE]
> **Goal:** Remove the mock AWS credentials from your Terraform code, enable the S3 remote backend, and add a `terraform-apply` job to the reusable workflow — so GitHub Actions can provision real AWS infrastructure using short-lived OIDC tokens instead of stored secrets.

## Context

In Step 1 you scaffolded the IaC with placeholder credentials so `terraform plan` could run locally. In Step 2 you built a pipeline that validates that plan. Now it's time to flip the switch:

- **Remove the mock credentials** from `infra/stacks/dev/main.tf` so Terraform doesn't use fake keys when the real OIDC token arrives
- **Enable the S3 backend** so state is stored safely in the shared bucket, not on the runner's ephemeral disk
- **Add a `terraform-apply` job** to `golden-path-ci.yml` that authenticates via OIDC and provisions the full AWS stack

Long-lived AWS access keys in GitHub Secrets are a security liability: they never expire, can't be scoped to a single workflow run, and leave a permanent blast radius if leaked. OIDC federation lets GitHub Actions request a short-lived token from AWS STS for exactly the duration of one job — zero static credentials, full auditability.

## What You Will Change

```text
infra/stacks/dev/main.tf       ← Remove mock creds, uncomment S3 backend
.github/workflows/
└── golden-path-ci.yml         ← Add terraform-apply + build-and-push jobs
└── todo-service-ci.yml        ← Enable apply + build flags on push to main
```

---

## Instructions

### 1. Verify the `AWS_ROLE_ARN` secret is in place

The OIDC job will reference this secret. Confirm it exists before touching any code:

**Steps:**

1. Go to your repo → **Settings** → **Secrets and variables** → **Actions**
2. Confirm `AWS_ROLE_ARN` appears under **Repository secrets**

If it's missing, ask your instructor for the ARN value — never paste it into workflow YAML.

---

### 2. Clean up `infra/stacks/dev/main.tf`

Open `infra/stacks/dev/main.tf`. Two changes are needed:

**Steps:**

1. **Remove the mock AWS credentials** from the provider block. Delete these lines:

```hcl
access_key                  = "mock-access-key"
secret_key                  = "mock-secret-key"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
```

After the change, the `provider "aws"` block should contain only `region`:

```hcl
provider "aws" {
  region = var.aws_region
}
```

2. **Uncomment the S3 backend block:**

```hcl
backend "s3" {
  bucket  = "pe-labs-terraform-state"
  region  = "us-east-2"
  encrypt = true
  # key is injected by CI: todo-service/<github-repo>/dev/terraform.tfstate
}
```

> [!TIP]
> Ask Copilot to handle both changes at once:
> _"In `infra/stacks/dev/main.tf`, remove the mock credential lines (access_key, secret_key, and all skip_\* lines) from the AWS provider block and uncomment the S3 backend block."\_

When the `terraform-apply` job runs, `aws-actions/configure-aws-credentials` injects the short-lived token into environment variables that the AWS provider picks up automatically.

> [!NOTE]
> The backend was commented out in Step 1 to allow local `terraform init` without credentials. Uncommenting it now enables remote state in the shared S3 bucket.

---

### 3. Validate and commit

**Steps:**

1. Open Copilot Chat in **Agent** mode and run:
   _"Validate my updated workflow and Terraform files are correct, then commit all three files to `feat/pe-golden-path` with a descriptive commit message and push."_

<details>
<summary>Or run manually if you prefer:</summary>

```bash
# Confirm mock credentials are gone
grep -n "mock-access-key\|skip_credentials" infra/stacks/dev/main.tf
# (should return no results)

# Confirm S3 backend is active
grep -n "backend \"s3\"" infra/stacks/dev/main.tf

# Confirm OIDC permission and apply job are present
grep -n "id-token\|terraform-apply\|build-and-push" .github/workflows/golden-path-ci.yml

# Validate YAML syntax
python3 -c "
import yaml, sys
for f in ['.github/workflows/golden-path-ci.yml', '.github/workflows/todo-service-ci.yml']:
    with open(f) as fh:
        yaml.safe_load(fh)
    print(f'Valid: {f}')
"

# Commit and push
git add infra/stacks/dev/main.tf .github/workflows/golden-path-ci.yml .github/workflows/todo-service-ci.yml
git commit -m "feat(iac): remove mock creds, enable S3 backend, add OIDC apply job"
git push origin feat/pe-golden-path
```

</details>

---

## Completion Criteria

Once your **Todo Service CI** pipeline completes successfully on `feat/pe-golden-path`, the step-detection workflow triggers automatically and will:

1. Close this issue
2. Open **Step 4 — Open PR**

Detection checks that `golden-path-ci.yml` contains a `terraform-apply` job with OIDC permission (`id-token: write`), `aws-actions/configure-aws-credentials`, and a `build-and-push` job with ECR login and ECS deployment steps.

> [!NOTE]
> When you open the **Actions** tab after pushing, you will notice the `terraform-apply` and `build-and-push` jobs show as **skipped** — this is expected. Both jobs are conditioned on a push to `main`, so they are intentionally skipped while the PR is open. They will run automatically once you merge to `main` in Step 4.

## Hints

> [!TIP]
>
> - If AWS credentials fail, verify the OIDC trust policy on the IAM role matches your repo's full name (`owner/repo`) — ask your instructor
> - The `terraform-apply` job must declare `permissions: id-token: write` at the job level (not just at the workflow level)
> - The `build-and-push` job should `needs: [terraform-apply]` — ECR repositories must exist before images can be pushed
> - If ECS tasks fail to start, check CloudWatch Logs at `/ecs/todo-service/backend` and `/ecs/todo-service/frontend`
> - **To verify the deployed service, open the ALB URL from your local machine — not from a Codespace.** The `alb_ingress_cidr` restricts ALB access to your own public IP. Codespaces run on GitHub-managed infrastructure with a different outbound IP, so requests to the load balancer from a Codespace will be blocked by the security group.
> - Ask Copilot: _"Why do I need to remove `access_key` and `secret_key` from the Terraform provider when using OIDC?"_

---

_Step 3 of 4 — [Previous: CI Pipeline] · [Next: Open PR]_
