.PHONY: init plan apply all validate fmt clean

STAGES := 0-org-setup 1-security 2-networking 3-project-factory 4-cicd

init:
	@for stage in $(STAGES); do \
		echo "=== init $$stage ==="; \
		cd stages/$$stage && terraform init -input=false && cd ../..; \
	done

validate:
	@for stage in $(STAGES); do \
		echo "=== validate $$stage ==="; \
		cd stages/$$stage && terraform init -backend=false -input=false && terraform validate && cd ../..; \
	done

fmt:
	terraform fmt -recursive .

plan:
	@./scripts/bootstrap.sh --plan-only all

apply:
	@./scripts/bootstrap.sh all

clean:
	@find stages -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find stages -name "tfplan" -delete 2>/dev/null || true

help:
	@echo "GCP Landing Zone — Makefile targets"
	@echo "  make init      Initialize all stages"
	@echo "  make validate  Validate Terraform syntax"
	@echo "  make fmt       Format Terraform files"
	@echo "  make plan      Plan all stages"
	@echo "  make apply     Apply all stages"
	@echo "  make clean     Remove .terraform directories"
