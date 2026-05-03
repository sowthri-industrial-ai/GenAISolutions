# Procurement Agentic Demo

[![CI](https://img.shields.io/badge/CI-pending-lightgrey)]()
[![Python](https://img.shields.io/badge/python-3.11-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

> A portfolio-grade demonstration of an enterprise agentic procurement workflow on Microsoft Azure AI Foundry. Generic, original, and built to showcase architectural patterns: multi-agent orchestration via Microsoft Agent Framework v1.0 + Foundry Workflows, retrieval-augmented generation through Foundry IQ, an MCP-native tool layer via Foundry Toolbox, guardrails, agent memory, and full observability through Foundry Control Plane.

---

## What This Demonstrates

| Pattern | Where to look |
|---|---|
| Multi-agent orchestration (MAF v1.0) | `backend/agents/`, `docs/PROJECT.md` §II.2.5 |
| Foundry Workflows (graph orchestration) | `backend/workflows/`, `docs/PROJECT.md` §II.2.4 |
| RAG via Foundry IQ (hybrid search + citations) | `backend/rag/`, `docs/PROJECT.md` §II.2.8 |
| MCP-native tool layer via Foundry Toolbox | `backend/tools/`, `docs/PROJECT.md` §II.2.6 |
| Guardrails (schema, injection, policy, confidence) | `backend/guardrails/`, `docs/PROJECT.md` §II.2.3 |
| Foundry Control Plane + App Insights observability | `backend/telemetry/`, `docs/PROJECT.md` §II.2.9 |
| Azure-native IaC (Bicep) | `infra/` |
| GitHub Actions CI/CD with OIDC | `.github/workflows/` |
| RAG + agent eval suite (incl. Foundry agent evals) | `tests/evals/` |

---

## Documentation

This project follows a **two-document reference model**:

- **[`docs/PROJECT.md`](docs/PROJECT.md)** — frozen architecture, components, tech stack, repo layout, working agreement, change-control protocol. The canonical reference.
- **[`docs/BACKLOG.md`](docs/BACKLOG.md)** — prioritized stories, acceptance criteria, and the live status tracker.

If both documents are at the same version, you have full project context.

Additional documents (added later in the build):

- `docs/adrs/` — Architecture Decision Records
- `docs/demo-script.md` — added in M4.5
- `docs/production-posture.md` — added in M4.7 (paper design)

### Architecture Decisions

- [ADR 0001 — Microsoft Foundry + Microsoft Agent Framework, not LangGraph standalone](docs/adrs/0001-foundry-and-maf-not-langgraph-standalone.md)

---

## Status

See **[`docs/BACKLOG.md`](docs/BACKLOG.md)** — Status Snapshot at the top.

The architecture is **frozen at v3.1** — see **[`docs/PROJECT.md`](docs/PROJECT.md)**.

---

## Quickstart

> _(Stub — fully populated in M4.4)_

```bash
# Prerequisites: Python 3.11, Docker, Azure CLI, azd
make install
make run            # local FastAPI on :8000  (added in M1.4)
make ui             # Streamlit on :8501      (added in M2.6)

# Azure lifecycle — single environment, daily teardown discipline (PROJECT.md §III.7)
export OWNER_TAG="your-name"
make azd-up         # provision + deploy (cold-start ≤8 min)
make azd-status     # show RG state, resources, recent lifecycle history
make azd-down       # tear down RG + purge soft-deleted Key Vault
```

See [`infra/README.md`](infra/README.md) for full details on the lifecycle scripts and prerequisites.

---

## Disclaimer

This repository is an original, generic demonstration project. It is **not affiliated with, derived from, or representative of** any employer's internal systems, products, or intellectual property. All data, schemas, and naming are synthetic.

---

## License

MIT
