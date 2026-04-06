.PHONY: setup doctor help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Interactive setup — configure identity and MCP connection
	@bash scripts/setup.sh

doctor: ## Check MCP connection and identity
	@bash scripts/doctor.sh
