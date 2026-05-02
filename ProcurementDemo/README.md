# Procurement Agentic Demo

[![CI](https://img.shields.io/badge/CI-pending-lightgrey)]()
[![Python](https://img.shields.io/badge/python-3.11-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

> A portfolio-grade demonstration of an enterprise agentic procurement workflow on Microsoft Azure. Generic, original, and built to showcase architectural patterns: multi-agent orchestration with LangGraph, durable workflows with Azure Durable Functions, RAG over Azure AI Search, an MCP-style tool layer, guardrails, memory, and full observability.

---

## What This Demonstrates

| Pattern | Where to look |
|---|---|
| Multi-agent LLM orchestration | `backend/agents/`, `docs/PROJECT.md` §II.2.5 |
| Durable, stateful workflows | `backend/orchestrators/`, `docs/PROJECT.md` §II.2.4 |
| RAG with hybrid search + citations | `backend/rag/`, `docs/PROJECT.md` §II.2.8 |
| MCP-style read-only tool layer | `backend/tools/`, `docs/PROJECT.md` §II.2.6 |
| Guardrails (schema, injection, policy, confidence) | `backend/guardrails/`, `docs/PROJECT.md` §II.2.3 |
| AI telemetry & cost observability | `backend/telemetry/`, `docs/PROJECT.md` §II.2.9 |
| Azure-native IaC (Bicep) | `infra/` |
| GitHub Actions CI/CD with OIDC | `.github/workflows/` |
| RAG + agent eval suite | `tests/evals/` |

---

## Documentation

This project follows a **two-document reference model**:

- **[`docs/PROJECT.md`](docs/PROJECT.md)** — frozen architecture, components, tech stack, repo layout, working agreement, change-control protocol. The canonical reference.
- **[`docs/BACKLOG.md`](docs/BACKLOG.md)** — prioritized stories, acceptance criteria, and the live status tracker.

If both documents are at the same version, you have full project context.

Additional documents (added later in the build):

- `docs/adrs/` — Architecture Decision Records
- `docs/demo-script.md` — added in M4.5
- `docs/foundry-migration.md` — added in M4.7 (paper design)

---

## Status

See **[`docs/BACKLOG.md`](docs/BACKLOG.md)** — Status Snapshot at the top.

The architecture is **frozen at v2.0** — see **[`docs/PROJECT.md`](docs/PROJECT.md)**.

---

## Quickstart

> _(Stub — fully populated in M4.4)_

```bash
# Prerequisites: Python 3.11, Docker, Azure CLI, azd
make install
make run            # local FastAPI on :8000
make ui             # Streamlit on :8501

# Deploy to Azure (single environment — main = live)
azd up
```

---

## Disclaimer

This repository is an original, generic demonstration project. It is **not affiliated with, derived from, or representative of** any employer's internal systems, products, or intellectual property. All data, schemas, and naming are synthetic.

---

## License

MIT
