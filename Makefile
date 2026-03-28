# ============================================================
# IaC LocalStack Platform — Makefile
# ============================================================

ENV ?= dev

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ---- LocalStack lifecycle ----

.PHONY: localstack-up
localstack-up: ## Start LocalStack in background
	docker compose up -d localstack
	@echo "Waiting for LocalStack to be healthy..."
	@until docker compose exec localstack curl -sf http://localhost:4566/_localstack/health; do sleep 2; done
	@echo "LocalStack is ready."

.PHONY: localstack-down
localstack-down: ## Stop and remove LocalStack containers and volumes
	docker compose down -v

.PHONY: localstack-status
localstack-status: ## Show LocalStack service health
	curl -s http://localhost:4566/_localstack/health | python3 -m json.tool

.PHONY: localstack-logs
localstack-logs: ## Stream LocalStack container logs
	docker compose logs -f localstack

# ---- State bootstrap ----

.PHONY: bootstrap
bootstrap: ## Create Terraform state S3 buckets in LocalStack
	chmod +x scripts/localstack-init.sh
	./scripts/localstack-init.sh

# ---- Terraform per-environment operations ----

.PHONY: init
init: ## terraform init for ENV (default: dev)
	chmod +x scripts/tf-apply.sh
	./scripts/tf-apply.sh $(ENV) init

.PHONY: plan
plan: ## terraform plan for ENV
	chmod +x scripts/tf-apply.sh
	./scripts/tf-apply.sh $(ENV) plan

.PHONY: apply
apply: ## terraform apply for ENV (prod requires CONFIRM_PROD=yes)
	chmod +x scripts/tf-apply.sh
	./scripts/tf-apply.sh $(ENV) apply

.PHONY: destroy
destroy: ## terraform destroy for ENV
	chmod +x scripts/tf-apply.sh
	./scripts/tf-apply.sh $(ENV) destroy

.PHONY: output
output: ## Show terraform outputs for ENV
	chmod +x scripts/tf-apply.sh
	./scripts/tf-apply.sh $(ENV) output

# ---- Validation and linting ----

.PHONY: fmt
fmt: ## Run terraform fmt on all .tf files
	terraform fmt -recursive .

.PHONY: validate
validate: ## Run terraform validate for ENV
	cd environments/$(ENV) && terraform validate

.PHONY: lint
lint: ## Run tflint on all modules and environments
	tflint --recursive || echo "Install tflint: https://github.com/terraform-linters/tflint"

# ---- AWS CLI helpers (via LocalStack) ----

.PHONY: ls-s3
ls-s3: ## List all S3 buckets in LocalStack
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 s3 ls

.PHONY: ls-iam
ls-iam: ## List all IAM roles in LocalStack
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 iam list-roles --query 'Roles[*].RoleName' --output table

.PHONY: ls-ec2
ls-ec2: ## List all EC2 instances in LocalStack
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 ec2 describe-instances --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name}' --output table

.PHONY: ls-alb
ls-alb: ## List all load balancers in LocalStack
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers --query 'LoadBalancers[*].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' --output table

# ---- Full workflow ----

.PHONY: full-demo
full-demo: localstack-up bootstrap ## Start LocalStack, bootstrap state, init+plan+apply dev
	$(MAKE) init ENV=dev
	$(MAKE) plan ENV=dev
	$(MAKE) apply ENV=dev
	@echo ""
	@echo "Demo complete. Run: make output ENV=dev"
	@echo "Inspect resources: make ls-s3 / ls-iam / ls-ec2 / ls-alb"
