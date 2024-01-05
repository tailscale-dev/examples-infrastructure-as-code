default: help

.PHONY: fix-terraform-examples
fix-terraform-examples: ## Fix examples-for-customers/terraform 
	./internal-scripts/fix-terraform-fmt.sh
	./internal-scripts/fix-variables-tailscale-install-scripts.sh

.PHONY: help
help: ## Display this information. Default target.
	@echo "Valid targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
