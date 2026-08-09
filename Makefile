# ============================================================
# gds-aidr-infrastructure - Makefile
# ============================================================
# Convenience wrappers for local operations.
#
# For Terraform work, select environment via env=<name>:
#   make env=security plan
#   make env=compute apply
#   make env=compute unlock LOCK_ID=<lock-id>
#
# For repo-wide hygiene:
#   make secrets-scan
#   make secrets-scan-full
#   make precommit
#
# ============================================================

env ?= compute
tf_dir := infrastructure/terraform/environments/$(env)
tf_log_dir := infrastructure/logs
secrets_log_dir := logs

.PHONY: help
help:
	@echo "gds-aidr-infrastructure — local operations"
	@echo ""
	@echo "Terraform (select env with env=<name>):"
	@echo "  make env=<name> init      Initialise Terraform"
	@echo "  make env=<name> plan      Run terraform plan"
	@echo "  make env=<name> apply     Run terraform apply"
	@echo "  make env=<name> unlock LOCK_ID=<id>"
	@echo "                            Force-unlock a stale state lock"
	@echo ""
	@echo "Environments: compute, security, containers, data-lake,"
	@echo "              monitoring, networking, production-iam"
	@echo ""
	@echo "Secrets scanning:"
	@echo "  make secrets-scan         Scan tracked files only (fast, recommended)"
	@echo "  make secrets-scan-full    Scan all files including gitignored (slow, verbose)"
	@echo ""
	@echo "Pre-commit hooks:"
	@echo "  make precommit-install    Install hooks locally (one-off setup)"
	@echo "  make precommit            Run all hooks against all files"

# ------------------------------------------------------------
# Terraform
# ------------------------------------------------------------

.PHONY: check-env
check-env:
	@if [ ! -d "$(tf_dir)" ]; then \
		echo "ERROR: environment '$(env)' not found at $(tf_dir)"; \
		exit 1; \
	fi

.PHONY: init
init: check-env
	cd $(tf_dir) && terraform init

.PHONY: plan
plan: check-env
	@mkdir -p $(tf_log_dir)
	cd $(tf_dir) && terraform plan -lock-timeout=60s | tee -a ../../../logs/terraform-plan.log

.PHONY: apply
apply: check-env
	@mkdir -p $(tf_log_dir)
	cd $(tf_dir) && terraform apply -lock-timeout=60s | tee -a ../../../logs/terraform-apply.log

.PHONY: unlock
unlock: check-env
	@if [ -z "$(LOCK_ID)" ]; then \
		echo "ERROR: LOCK_ID is required."; \
		echo "Copy the lock ID from the error message and run:"; \
		echo "  make env=$(env) unlock LOCK_ID=<lock-id>"; \
		exit 1; \
	fi
	cd $(tf_dir) && terraform force-unlock $(LOCK_ID)

# ------------------------------------------------------------
# Secrets scanning
# ------------------------------------------------------------

.PHONY: secrets-scan
secrets-scan:
	@mkdir -p $(secrets_log_dir)
	@echo "Scanning tracked files for secrets and account IDs..."
	gitleaks detect --source . --config .gitleaks.toml | tee -a $(secrets_log_dir)/gitleaks.log

.PHONY: secrets-scan-full
secrets-scan-full:
	@mkdir -p $(secrets_log_dir)
	@echo "Scanning ALL files (including gitignored) — expect false positives in .archive/ and .development/"
	gitleaks detect --source . --config .gitleaks.toml --no-git | tee -a $(secrets_log_dir)/gitleaks-full.log

# ------------------------------------------------------------
# Pre-commit
# ------------------------------------------------------------

.PHONY: precommit-install
precommit-install:
	pre-commit install

.PHONY: precommit
precommit:
	pre-commit run --all-files