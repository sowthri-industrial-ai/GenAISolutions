# Install method: pip (Python 3.11 venv at .venv, dev extras from pyproject.toml)
# Targets are POSIX-portable across macOS and Linux.

PYTHON ?= python3.11
VENV   := .venv
BIN    := $(VENV)/bin

.PHONY: install lint format test clean

install:
	$(PYTHON) -m venv $(VENV)
	$(BIN)/python -m pip install --upgrade pip
	$(BIN)/pip install -e ".[dev]"

lint:
	$(BIN)/ruff check .
	$(BIN)/black --check .

format:
	$(BIN)/ruff check --fix .
	$(BIN)/black .

test:
	$(BIN)/pytest

clean:
	rm -rf $(VENV) .pytest_cache .ruff_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +

# --- Azure lifecycle (M1.3 placeholders; M1.3.5 will add timing + history) ---
# Per PROJECT.md §III.7 — daily teardown / cold-start discipline.

.PHONY: azd-up azd-down azd-status

azd-up:
	@start=$$(date +%s); \
	azd up --no-prompt; \
	end=$$(date +%s); \
	echo "azd up completed in $$((end - start))s"; \
	rg=$$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_RESOURCE_GROUP=/{gsub(/"/,"",$$2); print $$2}'); \
	if [ -n "$$rg" ]; then az group show --name "$$rg" --output table; \
	else echo "AZURE_RESOURCE_GROUP not set in azd env yet"; fi

azd-down:
	@start=$$(date +%s); \
	azd down --force --purge --no-prompt; \
	end=$$(date +%s); \
	echo "azd down completed in $$((end - start))s"; \
	rg=$$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_RESOURCE_GROUP=/{gsub(/"/,"",$$2); print $$2}'); \
	if [ -n "$$rg" ] && az group show --name "$$rg" >/dev/null 2>&1; then \
		echo "WARN: resource group $$rg still exists after azd down" >&2; exit 1; \
	else \
		echo "Resource group fully purged"; \
	fi

azd-status:
	@rg=$$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_RESOURCE_GROUP=/{gsub(/"/,"",$$2); print $$2}'); \
	if [ -z "$$rg" ]; then echo "No azd env yet — run 'azd init' or 'make azd-up' first"; exit 0; fi; \
	if az group show --name "$$rg" >/dev/null 2>&1; then \
		echo "Resource group: $$rg (exists)"; \
		az resource list -g "$$rg" --output table; \
		az stack sub list --query "[?contains(name, '$$rg')].{name:name, state:provisioningState, lastUpdated:systemData.lastModifiedAt}" --output table 2>/dev/null || true; \
	else \
		echo "Resource group: $$rg (not deployed)"; \
	fi
