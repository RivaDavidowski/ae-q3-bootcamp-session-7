---
description: Configure the Terraform dev stack to deploy the todo-service using the Slalom PE Lab golden-path module
---

Read the requirements from #file:../../context/iac-requirements.md and the coding standards from #file:../copilot-instructions.md before writing any files.

Your task is to add the `todo_service` module block, input variables, and outputs to `infra/stacks/dev/main.tf` so it provisions the todo-service infrastructure using the Slalom PE Lab golden-path module.

**Module block to add** (append after the existing `provider "aws"` and `variable "aws_region"` blocks):
```hcl
# ---------------------------------------------------------------
# Todo Service — provisioned via the Slalom PE Lab ECS App golden-path module
# (local copy of github.com/Slalom/slalom-terraform-pe-lab-ecs-app v1.0.4)
# The module creates an ECS cluster, ALB, ECR repos, IAM roles, networking,
# and CloudWatch log groups.
# ---------------------------------------------------------------
module "todo_service" {
  source = "../../modules/todo-service"

  environment       = "dev"
  create_networking = true
  alb_ingress_cidr  = var.alb_ingress_cidr

  backend_image  = var.backend_image
  frontend_image = var.frontend_image

  desired_count         = 1
  cpu                   = 256
  memory                = 512
  log_retention_in_days = 7
  ecr_force_delete      = true
}
```

**Input variables to add** (after the module block):
- `alb_ingress_cidr` — string, required, description: "CIDR block allowed to reach the Application Load Balancer on port 80. Ask your instructor for the correct value."
- `backend_image` — string, default `""`, description: "Docker image URI for the backend container. Leave empty to use the ECR repo managed by this module."
- `frontend_image` — string, default `""`, description: "Docker image URI for the frontend nginx container. Leave empty to use the ECR repo managed by this module."

**Outputs to add** (after the variables):
- `service_url` → `module.todo_service.service_url`
- `cluster_name` → `module.todo_service.cluster_name`
- `backend_ecr_repository_url` → `module.todo_service.backend_ecr_repository_url`
- `frontend_ecr_repository_url` → `module.todo_service.frontend_ecr_repository_url`

**Keep the S3 backend block commented out** — it is intentionally disabled for Steps 1–2 so `terraform init` works locally without AWS credentials. It will be uncommented in Step 3. Keep the mock provider block for local validation (Steps 1–2). Do not modify `infra/modules/todo-service/` — that is the golden-path module, only the stack that calls it should be updated.
