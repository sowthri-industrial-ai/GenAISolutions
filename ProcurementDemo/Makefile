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

# --- Azure lifecycle (M1.3.5: instrumented; logs to tests/cold-start-history.csv) ---
# Per PROJECT.md §III.7 — daily teardown / cold-start discipline.
# Implementation in infra/scripts/azd-lifecycle.sh; this file stays declarative.

.PHONY: azd-up azd-down azd-status

azd-up:
	@bash infra/scripts/azd-lifecycle.sh up

azd-down:
	@bash infra/scripts/azd-lifecycle.sh down

azd-status:
	@bash infra/scripts/azd-lifecycle.sh status
