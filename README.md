# Infrastructure as Code Platform — Terraform + LocalStack

A production-grade Terraform IaC platform that provisions a full AWS-equivalent infrastructure
stack locally using LocalStack. No real AWS account needed. No cloud spend. Full module structure,
remote state management, multi-environment promotion, and least-privilege IAM.

---

## Skills Demonstrated

| Skill | Evidence |
|---|---|
| Terraform module architecture | Reusable VPC, Compute, Storage, IAM modules with full variable validation |
| AWS architecture knowledge | VPC with public/private subnets, NAT gateway, IGW, route tables, flow logs |
| Production EC2 patterns | Launch Template with IMDSv2, ASG with instance refresh, target tracking scaling |
| ALB configuration | Target group health checks, listener rules, access logging, 5xx alarms |
| IAM least-privilege design | Scoped policies per service, condition keys by region, OIDC trust for CI/CD |
| S3 security hardening | Block public access, SSE encryption, versioning, lifecycle policies, HTTPS enforcement |
| State management | S3 backend with versioning, separate state per environment |
| Multi-environment IaC | Dev (minimal) and Prod (HA, 3 AZs, NAT gateway) from same module base |
| CloudWatch integration | CPU alarms, ALB 5xx alarms, EC2 metric agent via user data |
| Terraform input validation | Custom validation blocks on CIDR, instance type, subnet type |

---

## Architecture

```
environments/
  dev/   -- 2 AZs, no NAT, t3.micro, ASG 1-2, force_destroy buckets
  prod/  -- 3 AZs, NAT gateway, t3.small, ASG 2-10, versioned buckets, OIDC CI/CD role

Each environment uses:
  modules/vpc/      -- VPC, subnets (public+private), IGW, NAT, route tables, flow logs
  modules/compute/  -- Launch Template (IMDSv2), ASG, ALB, Target Group, CloudWatch alarms
  modules/storage/  -- S3 with encryption, versioning, lifecycle, HTTPS policy
  modules/iam/      -- EC2 role + policies (S3, CloudWatch, SSM), CI/CD OIDC role

Remote state: S3 backend in LocalStack (separate bucket per env)
```

---

## Project Structure

```
iac-localstack-platform/
  modules/
    vpc/
      main.tf         # VPC, subnets, IGW, NAT, route tables, flow logs
      variables.tf    # Typed inputs with validation
      outputs.tf
    compute/
      main.tf         # ALB, ASG, Launch Template (IMDSv2), CloudWatch alarms
      variables.tf
      outputs.tf
      user_data.sh.tpl  # EC2 bootstrap: CW agent, SSM, app service
    storage/
      main.tf         # S3: encryption, versioning, lifecycle, HTTPS policy, CORS
      variables.tf
      outputs.tf
    iam/
      main.tf         # EC2 role, scoped policies, OIDC CI/CD role
      variables.tf
      outputs.tf
  environments/
    dev/
      main.tf         # Dev wiring: minimal sizing, no NAT
      variables.tf
      outputs.tf
    prod/
      main.tf         # Prod wiring: HA, NAT, OIDC CI/CD role
      variables.tf
      outputs.tf
  scripts/
    localstack-init.sh  # Bootstrap state buckets before terraform init
    tf-apply.sh         # Wrapper with env validation and prod safety gate
  docker-compose.yml    # LocalStack container definition
  Makefile              # All operations as targets
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker | 24+ | https://docs.docker.com/engine/install/ |
| Terraform | 1.6+ | https://developer.hashicorp.com/terraform/install |
| AWS CLI v2 | 2.x | https://aws.amazon.com/cli/ |

---

## Quick Start

### Step 1 — Start LocalStack

```bash
make localstack-up
```

Verify it is healthy:

```bash
make localstack-status
```

Expected: JSON showing all services as "running" or "available".

### Step 2 — Bootstrap Terraform state buckets

```bash
make bootstrap
```

This creates `s3://terraform-state-dev`, `s3://terraform-state-staging`, and
`s3://terraform-state-prod` inside LocalStack with versioning enabled.

### Step 3 — Initialize Terraform for dev

```bash
make init ENV=dev
```

### Step 4 — Plan the dev environment

```bash
make plan ENV=dev
```

Review the plan. Expected: ~25 to 35 resources covering VPC, subnets, IGW, route tables,
S3 buckets, IAM roles, Launch Template, ASG, ALB, Target Group, and CloudWatch alarms.

### Step 5 — Apply

```bash
make apply ENV=dev
```

### Step 6 — Inspect created resources

```bash
make ls-s3      # S3 buckets
make ls-iam     # IAM roles
make ls-ec2     # EC2 instances (simulated)
make ls-alb     # Load balancers
make output ENV=dev   # Terraform outputs
```

### Step 7 — Run the full demo in one command

```bash
make full-demo
```

### Step 8 — Apply production (with safety gate)

```bash
make init ENV=prod
make plan ENV=prod
CONFIRM_PROD=yes make apply ENV=prod
```

Production apply requires `CONFIRM_PROD=yes` explicitly — this is intentional.
Destroy is blocked entirely for prod via the script.

---

## Module Details

### VPC Module

- Accepts a map of subnets with type `public` or `private`
- Creates separate route tables per visibility tier
- NAT Gateway is optional (dev disables it for cost)
- Flow logs to S3 when `enable_flow_logs = true`
- Validates CIDR blocks and subnet types with Terraform validation blocks

### Compute Module

- Launch Template with IMDSv2 enforced (`http_tokens = required`)
- Encrypted EBS root volume (gp3)
- Instance refresh strategy for zero-downtime ASG rolling updates
- Target tracking scaling policy on CPU utilization
- CloudWatch alarms for CPU and ALB 5xx errors
- User data bootstraps CloudWatch agent, SSM, and a systemd app service

### Storage Module

- All public access blocked by default
- SSE-AES256 or SSE-KMS depending on whether a KMS key ARN is provided
- Lifecycle: IA at 30 days, Glacier at 90 days, version cleanup at 30 days
- Optional HTTPS-only bucket policy
- Optional access logging to a separate log bucket

### IAM Module

- EC2 role path `/app/` for RBAC-style organization
- Policies scoped to specific bucket prefixes and log group paths
- Region condition key on EC2 assume-role trust
- Optional OIDC trust for GitHub Actions — zero static credentials
- CI/CD policy scoped to ASG name prefix and ECR in the configured region

---

## Teardown

```bash
make destroy ENV=dev
make localstack-down
```

---

## Screenshots to Capture for GitHub README

1. `terraform plan` output in terminal — showing resource count and green "Plan: X to add"
   (run `make plan ENV=dev` and screenshot the full output)

2. `make ls-s3` output — showing all provisioned S3 buckets in LocalStack
   (terminal screenshot of the table)

3. `make ls-iam` output — showing IAM roles with the /app/ and /cicd/ path prefixes
   (terminal screenshot of the table)

4. `make ls-alb` output — showing the ALB with DNS name and active state
   (terminal screenshot)

5. `terraform output -json` for the dev environment — showing all output values
   (terminal screenshot with `make output ENV=dev`)

6. LocalStack health endpoint — `make localstack-status` showing all services running
   (terminal screenshot)

---

## GitHub Repo Name

`iac-localstack-platform`
