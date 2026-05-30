.DEFAULT_GOAL := help

ENV      ?= dev
CHART    ?=
PLAYBOOK ?= site

.PHONY: help \
        setup \
        check \
        provision \
        install destroy \
        secrets-init secrets-encrypt secrets-decrypt secrets-check \
        lint \
        tf-init tf-plan tf-apply tf-destroy

help: ## Show available targets and variables
	@printf '\n\033[1mHomelab\033[0m\n\n'
	@printf '\033[1mVariables\033[0m\n'
	@printf '  \033[1mENV\033[0m=dev|prod       environment to target (default: dev)\n'
	@printf '  \033[1mCHART\033[0m=<name>        limit secrets operations to one chart\n'
	@printf '  \033[1mPLAYBOOK\033[0m=<name>     Ansible playbook to run   (default: site)\n'
	@printf '\n\033[1mTargets\033[0m\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-z][a-z-]*:.*## / { printf "  \033[1m%-22s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '\n'

# ── Validation ────────────────────────────────────────────────────────────────

check: ## Validate tools, Helm plugins, and Kubernetes cluster access
	./scripts/check-requirements.sh
	./scripts/check-kubernetes.sh

# ── Cluster provisioning ──────────────────────────────────────────────────────

provision: ## Provision the K3s cluster via Ansible  [PLAYBOOK=site]
	./metal/k3s/run.sh $(PLAYBOOK)

# ── Helmfile deployment ───────────────────────────────────────────────────────

install: ## Deploy all helmfile releases for ENV  [ENV=dev]
	./scripts/install-helmfiles.sh $(ENV)

destroy: ## Tear down all helmfile releases for ENV  [ENV=dev]
	./scripts/destroy-helmfiles.sh $(ENV)

# ── Secrets management ────────────────────────────────────────────────────────

secrets-init: ## Initialise secrets from templates for ENV  [ENV=dev]
	./scripts/init-secrets.sh $(ENV)

secrets-encrypt: ## Encrypt secrets for ENV, optionally scoped to CHART  [ENV=dev] [CHART=]
	./scripts/sops-encrypt-secrets.sh $(ENV) $(CHART)

secrets-decrypt: ## Decrypt secrets for ENV, optionally scoped to CHART  [ENV=dev] [CHART=]
	./scripts/sops-decrypt-secrets.sh $(ENV) $(CHART)

secrets-check: ## Validate secrets are present and complete for all environments
	./scripts/check-secrets.sh

# ── Linting ───────────────────────────────────────────────────────────────────

lint: ## Run all linters (pre-commit, helm charts, helmfile)  [ENV=dev]
	pre-commit run --all-files

# ── Terraform ────────────────────────────────────────────────────────────────

tf-init: ## Initialise Terraform (run once or after provider changes)
	terraform -chdir=terraform init

tf-plan: ## Show Terraform execution plan
	terraform -chdir=terraform plan

tf-apply: ## Apply Terraform changes
	terraform -chdir=terraform apply

tf-destroy: ## Destroy all Terraform-managed resources
	terraform -chdir=terraform destroy

# ── Setup ─────────────────────────────────────────────────────────────────────

setup: ## Bootstrap local environment (tools, helm plugins, git hooks, terraform)
	mise install
	./scripts/install-helm-plugins.sh
	pre-commit install
	pre-commit install --hook-type commit-msg
	terraform -chdir=terraform init
