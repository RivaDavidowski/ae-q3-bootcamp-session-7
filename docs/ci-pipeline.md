# CI Pipeline

The Todo Service CI pipeline is split into a reusable workflow, `.github/workflows/golden-path-ci.yml`, and a small caller, `.github/workflows/todo-service-ci.yml`. This lets service teams adopt the same validation and deployment path without duplicating workflow logic.

## Reusable Workflow

`golden-path-ci.yml` is triggered only with `workflow_call`. It accepts Node.js and Terraform version inputs, switches for Terraform planning, applying, and image publishing, plus an `aws_role_arn` secret for AWS OIDC authentication.

| Job               | What it does                                                                                                                                                         | Why it exists                                                                                              |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `lint`            | Installs workspace dependencies and runs ESLint for the backend and frontend.                                                                                        | Catches JavaScript issues before tests or container builds.                                                |
| `test`            | Runs backend Jest tests with coverage and writes the coverage totals to the workflow summary.                                                                        | Enforces the backend's configured 80% global coverage threshold.                                           |
| `security-scan`   | Runs Checkov against `infra/` when Terraform planning is enabled.                                                                                                    | Prevents high-severity infrastructure policy issues from proceeding.                                       |
| `terraform-plan`  | Authenticates to AWS with OIDC, initializes the dev stack with its unique S3 state key, produces a Terraform plan, summarizes it, and uploads the `tfplan` artifact. | Reviews intended infrastructure changes before apply and provides the approved plan to the deployment job. |
| `docker-build`    | Builds backend and frontend Docker images on pull requests without pushing them.                                                                                     | Confirms both Dockerfiles remain buildable before merge.                                                   |
| `terraform-apply` | Runs only when enabled, downloads the approved plan artifact, and applies it with OIDC credentials.                                                                  | Restricts state-changing infrastructure deployment to the caller's explicit gate.                          |
| `build-and-push`  | Resolves ECR repositories, builds and tags both images, pushes them to ECR, then forces an ECS deployment.                                                           | Publishes verified application images and rolls out the service after its infrastructure exists.           |

## Required Checks

The caller enables Terraform planning for every pull request and push. Configure these as required status checks in branch protection:

| Check            | Validation                                                                        |
| ---------------- | --------------------------------------------------------------------------------- |
| `lint`           | Frontend and backend code conform to ESLint rules.                                |
| `test`           | Backend Jest tests pass and meet the configured coverage threshold.               |
| `security-scan`  | Checkov finds no high-severity IaC findings.                                      |
| `terraform-plan` | The Terraform configuration initializes and produces a reviewable execution plan. |
| `docker-build`   | Both service container images build successfully on pull requests.                |

## Adopt The Workflow

Create `.github/workflows/todo-service-ci.yml` in the adopting service repository. This is the minimum caller for the workflow in this repository:

```yaml
name: Todo Service CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  call-golden-path:
    uses: ./.github/workflows/golden-path-ci.yml
    with:
      node_version: "20"
      run_terraform_plan: true
      run_terraform_apply: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
      build_and_push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

The caller-level `id-token: write` permission is required. A reusable workflow cannot obtain an OIDC token unless its caller grants that permission.

## Configure AWS OIDC

1. Create an AWS IAM role that trusts GitHub Actions OIDC for the intended repository and branch or environment. Grant it the AWS permissions required to read state, plan the dev stack, and, for deploys, manage the provisioned ECS, ECR, and related resources.
2. In GitHub, open the repository **Settings**, then **Secrets and variables**, then **Actions**. Add a repository secret named `AWS_ROLE_ARN` whose value is the IAM role ARN.
3. Keep the caller mapping `aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}`. The reusable workflow intentionally uses only its declared `secrets.aws_role_arn` input, so it does not depend on a particular repository secret name.

The plan, apply, and image-publishing jobs use `aws-actions/configure-aws-credentials@v4` with this role ARN. No long-lived AWS access keys are stored in GitHub.
