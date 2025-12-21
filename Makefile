default: help

.PHONY: terraform-check-tflint
terraform-check-tflint: ## Run 'terraform-check-tflint' github actions with https://github.com/nektos/act
	act -j terraform-check-tflint

.PHONY: check-terraform-examples
terraform-check-examples: ## Run specific 'check' github actions with https://github.com/nektos/act
	act -j terraform-check-fmt
	act -j terraform-check-variables-tailscale-install-scripts

.PHONY: terraform-fmt
terraform-fmt: ## Run 'terraform-fmt' github actions with https://github.com/nektos/act
	terraform fmt -recursive

.PHONY: help
help: ## Display this information. Default target.
	@echo "Valid targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
