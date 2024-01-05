default: help

.PHONY: check-terraform-examples
check-terraform-examples: ## Run specific 'check' github actions with https://github.com/nektos/act
	act -j check-terraform-fmt
	act -j check-variables-tailscale-install-scripts

.PHONY: help
help: ## Display this information. Default target.
	@echo "Valid targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
