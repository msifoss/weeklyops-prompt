.PHONY: setup install-app doctor help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Terminal users — configure identity and MCP connection for Claude Code
	@bash scripts/setup.sh

install-app: ## Desktop users — add WeeklyOps to Claude Desktop app
	@bash scripts/install-app.sh

doctor: ## Check MCP connection and identity
	@bash scripts/doctor.sh
