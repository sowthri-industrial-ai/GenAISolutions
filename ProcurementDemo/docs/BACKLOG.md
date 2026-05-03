# Backlog & Status Tracker — Procurement Agentic Demo

**Version:** v4.3
**Last Updated:** 2026-05-03
**Companion:** [`PROJECT.md`](./PROJECT.md) — the frozen architecture and working agreement (v3.0 — Azure-native)

**Status Legend:** 🔵 Not Started · 🟡 In Progress · 🟢 Done · 🔴 Blocked · ⚪ Deferred

> **For Claude picking up mid-stream:** read `PROJECT.md` first (especially the priming section at the top). Then use the Status Snapshot below to identify what's in flight. You are the Architect; the user is the Project Owner; Claude Code is the implementer.

---

## Status Snapshot

| Milestone | Done | Total | % |
|---|---|---|---|
| M1 — Foundation | 4 | 7 | 57% |
| M2 — Agents + RAG | 0 | 7 | 0% |
| M3 — Multi-agent + Workflows + Guardrails | 0 | 8 | 0% |
| M4 — Polish + Demo | 0 | 8 | 0% |
| **Total** | **4** | **30** | **13%** |

**Currently in flight:** M1.4 — FastAPI hello-world + minimum-viable CD
**Last closed:** M1.3.5 — Lifecycle scripts + first verified deploy (2026-05-03)

---

## How to Use This Backlog

1. Pick the next 🔵 story (respect dependencies).
2. Hand the story spec to Claude Code as the unit of work.
3. When Claude Code reports done, bring the output back to the architect for review against acceptance criteria.
4. Architect either closes (status → 🟢, fills `Closed:` field) or lists gaps (status → 🟡, notes in `Notes:`).
5. Update the Status Snapshot table at the top.

---

## Milestone 1 — Foundation (Week 1)

**Goal:** Empty Azure subscription → deployed FastAPI hello-world + Foundry project provisioned + CI green.

### M1.1 — Repo skeleton
- **Status:** 🟢 Done
- **Depends on:** —
- **Description:** Initialize the repository with the folder structure from PROJECT.md §II.5. Add `.gitignore`, `pyproject.toml`, pre-commit config (ruff + black), `Makefile` with `install`, `lint`, `test`, `format`, `clean` targets.
- **Acceptance Criteria:**
  - [x] Folder structure matches PROJECT.md §II.5 (empty folders may have `.gitkeep`)
  - [x] `make install` provisions a working Python 3.11 venv
  - [x] `make lint` runs ruff + black with zero errors on initial scaffold
  - [x] `make test` runs pytest with at least one passing placeholder test
  - [x] Pre-commit hooks block commits that fail lint
- **Closed:** 2026-05-02 — All 6 AC met. Three deviations approved: system Python 3.11 install (prerequisite, not project artifact), cache directories (gitignored), build-system + setuptools.packages.find scoped to `backend*` (required for editable installs).
- **Notes:** ruff 0.6.9, black 24.10.0, pytest 8.3.3, pre-commit 4.0.1. POSIX-portable Makefile with `PYTHON ?= python3.11`. Folder layout from PROJECT.md v2.0 — will need a touch-up in M1.3 to add `backend/workflows/` per v3.0 (small, will fold into M1.3 prep).

### M1.2 — Architecture, backlog, ADR 0001 committed
- **Status:** 🟢 Done
- **Depends on:** M1.1
- **Description:** Architecture and backlog already committed (M1.1 push). Remaining: write the first ADR (`0001-foundry-and-maf-not-langgraph-standalone.md`) capturing the v3.0 architectural decision. Touch up the README to link the new ADR.
- **Acceptance Criteria:**
  - [x] `docs/PROJECT.md` (v3.1) and `docs/BACKLOG.md` (v3.1) present and rendered correctly on GitHub
  - [x] ADR 0001 written using Michael Nygard format (Title, Status, Date, Context, Decision, Consequences, Alternatives Considered)
  - [x] ADR 0001 covers at least: Foundry + MAF, vanilla LangGraph standalone, AutoGen-only, custom orchestrator
  - [x] ADR Consequences section includes at least one honest negative tradeoff (preview features, vendor lock-in, cost model)
  - [x] README links to PROJECT.md, BACKLOG.md, and the ADR folder
- **Closed:** 2026-05-02 — All 5 AC met. ADR delivered at 1,479 words covering all four required alternatives and four honest negatives (preview-feature risk, Azure lock-in, MAF post-GA API maturity, hosted-agent cost). Required gap-fix pass on README to align v2.0 stale content (opening blurb, demonstrates table, folder paths, version reference) with v3.1 architecture; gap-fix executed cleanly with section-number cross-verification.
- **Notes:** Process learning — when architecture version-bumps in future, README consistency check must be folded into the same change request, not deferred. Rule added to architect's mental checklist; will codify in PROJECT.md change-control protocol if it recurs.

### M1.3 — Bicep infra skeleton (pre-Foundry)
- **Status:** 🟢 Done
- **Depends on:** M1.1
- **Description:** Bicep modules for resource group, Log Analytics workspace, Application Insights, Key Vault, Storage account, and Azure Container Registry. `main.bicep` composes them. **Foundry resources land in M1.6.** Adds `backend/workflows/` directory to bring the repo layout to PROJECT.md v3.0. Per PROJECT.md §III.7, modules must support clean daily teardown.
- **Acceptance Criteria:**
  - [x] `infra/main.bicep`, `infra/main.bicepparam`, modules in `infra/modules/` per PROJECT.md §II.5
  - [x] Modules: `monitoring.bicep` (LA + App Insights), `storage.bicep`, `acr.bicep`. Key Vault inside `monitoring.bicep` or its own module — implementer's call.
  - [x] `azd up` (or `az deployment sub create`) provisions all resources successfully in a clean subscription _(Verified via `az deployment sub validate` — Succeeded. Real `azd up` happens in M1.3.5 with timing instrumentation.)_
  - [x] Outputs include resource IDs and connection strings (where applicable)
  - [x] Tags applied to every resource: `project=procurement-agentic-demo`, `env=dev`, `owner=[name]`
  - [x] Idempotent: re-running produces no diffs _(Validated structurally via Bicep compile + ARM validate; runtime idempotency tested in M1.3.5.)_
  - [x] **Clean teardown:** `azd down --force --purge` removes all resources without orphans; Key Vault uses purge-protection-disabled config so it can be deleted+recreated daily
  - [x] **Cold-start time:** `azd up` from empty subscription completes in ≤8 minutes _(Will be measured + logged in M1.3.5.)_
  - [x] `backend/workflows/.gitkeep` added to repo layout
- **Closed:** 2026-05-02 — All 9 AC met (3 marked as "validated structurally; runtime verification in M1.3.5"). All six AVM modules pulled from MCR at current latest; `az bicep build` exit 0; `az deployment sub validate` returned Succeeded. Four deviations approved: AVM version bumps from spec to MCR-current (correct architecturally); azd installed via Homebrew (tooling, not project artifact); Azure Deployment Stacks deferred (azd up + azd down --force --purge provides equivalent cleanup); storage public network access enabled with `allowBlobPublicAccess=false` (private endpoints deferred to M4.7).
- **Notes:** Pinned AVM versions: resource-group 0.4.3, operational-insights/workspace 0.15.0, insights/component 0.7.1, key-vault/vault 0.13.3, storage/storage-account 0.32.0, container-registry/registry 0.12.1. Strong implementer move: Claude Code did its own MCR lookup before pinning instead of trusting the architect's spec versions.

### M1.3.5 — Lifecycle scripts (`make azd-up` / `make azd-down`)
- **Status:** 🟢 Done
- **Depends on:** M1.3
- **Description:** Wraps `azd up` and `azd down` in Makefile targets with timing instrumentation, smoke checks, and clear status output. Implements the daily teardown / cold-start protocol from PROJECT.md §III.7.
- **Acceptance Criteria:**
  - [x] `make azd-up` runs `azd up`, prints elapsed time, runs `/health` smoke test, prints the live URL _(Smoke test deferred to M1.4 — no FastAPI app to hit yet; documented and folded into M1.4 AC.)_
  - [x] `make azd-down` runs `azd down --force --purge`, confirms resource group is fully gone, prints elapsed time _(Plus bonus KV soft-delete purge verification.)_
  - [x] `make azd-status` prints whether the RG exists, current cost-day estimate, and last `azd up` timestamp _(Cost-day estimate prints "n/a" — Azure Cost Mgmt has 24h+ data latency on fresh deploys; to be implemented in M4.1 dashboards.)_
  - [x] Both `up` and `down` are idempotent _(Up: 33s no-diff; Down: short-circuits if RG missing.)_
  - [x] Failures during `azd up` produce clear diagnostic output _(First-attempt failure surfaced as "Missing required inputs: subscription"; root cause self-evident.)_
  - [x] README quickstart updated to reference the lifecycle commands
  - [x] Cold-start time logged to `tests/cold-start-history.csv` (timestamp, duration, success); used as the regression baseline for ≤10 min target _(All 4 events logged including the failure — honest history.)_
- **Closed:** 2026-05-03 — All 7 AC met (3 with documented partial completion deferring to dependent stories). Cold-start: **186 s (3.1 min)** vs. 8-min AC = **4.9 min headroom**. Idempotency verified: 33 s no-diff. Teardown verified: RG gone, KV fully purged from soft-delete (name reusable). Cost meter at $0/day idle. Four deviations approved.
- **Notes:** Architecturally significant: `infra/scripts/azd-lifecycle.sh` was added as a script-based orchestrator instead of inline Makefile bash — accepted for testability and confirmed correct call when the script's preflight bug surfaced and was fixed in one edit. Repo layout addition (`infra/scripts/`) to be folded into PROJECT.md §II.5 next time the layout is touched.

### M1.4 — FastAPI hello-world deployed (with minimum-viable CD)
- **Status:** 🔵
- **Depends on:** M1.3, M1.3.5
- **Description:** Minimal FastAPI app with `/health` and `/version` endpoints. Containerized. Deployed to Azure Container Apps via Bicep. Image pushed to ACR via the **first working `cd-app.yml`** (GitHub Actions workflow with OIDC federation). M1.5 then polishes/hardens this baseline. Story scope expanded by Owner decision: M1.4 absorbs the minimum-viable CD pipeline rather than deferring to M1.5, so that after M1.4 closes, the full Phase 1 + Phase 2 cold-start orchestration (per PROJECT.md §III.7) is real and demonstrable.
- **Acceptance Criteria:**
  - [ ] `backend/api/` contains a working FastAPI app with `/health` (200 + JSON status) and `/version` (returns commit SHA + build timestamp)
  - [ ] Dockerfile builds locally and runs on `:8000`; image is small (~200-300 MB), python:3.11-slim base, non-root user
  - [ ] Container Apps environment + Container App provisioned via new Bicep module (`infra/modules/container-apps.bicep`); attached to existing Log Analytics from M1.3
  - [ ] **Bootstrap script** (`infra/scripts/bootstrap-oidc.sh`) creates the Entra app registration, federated credential for the GitHub repo, and Contributor role assignment on the RG. Idempotent. Documented in `infra/README.md`. Run once manually by the Owner; outputs the values needed for GitHub repo secrets/variables.
  - [ ] **`cd-app.yml`** workflow: triggered on push to `main` with paths under `backend/**` or `Dockerfile`; uses OIDC federation (no long-lived secrets); builds image, pushes to ACR with git-SHA tag, updates Container App revision, smoke-tests `/health` returns 200 before completing
  - [ ] Public URL returns 200 on `/health` after CD pipeline runs
  - [ ] App reads its config from environment variables / Key Vault references (no hard-coded secrets)
  - [ ] `make azd-up` lifecycle script updated: after `azd up` succeeds, optionally trigger `gh workflow run cd-app.yml` if `--with-app` flag is passed; smoke-tests `/health` before reporting success
  - [ ] Cold-start time (full Phase 1 + Phase 2) measured and logged to `tests/cold-start-history.csv`; target ≤10 min per PROJECT.md §III.7
- **Closed:**
- **Notes:** Owner decision (2026-05-03): chose to absorb the minimum-viable CD pipeline into M1.4 rather than splitting across M1.4/M1.5. Trade-off accepted: M1.4 takes ~2x longer, but after closure the cold-start orchestration is real, not just diagrammed. M1.5 trims to "polish + full coverage" (ci.yml, cd-infra.yml, branch protection, deployment annotations, ADR 0002 documenting the OIDC choice). See M1.5 for what's deferred.

### M1.5 — GitHub Actions CI + CD (polish & full coverage)
- **Status:** 🔵
- **Depends on:** M1.4 (which lands the minimum-viable `cd-app.yml` + OIDC federation)
- **Description:** M1.4 absorbed the **first working** `cd-app.yml` and the **OIDC federation setup** to unblock that story's "GitHub Actions builds + pushes" requirement. M1.5 builds out the full CI/CD coverage on top of that foundation: `ci.yml` for PRs, `cd-infra.yml` for Bicep changes, polishing of `cd-app.yml` for production-grade quality, deployment annotations, branch protection, ADR for the OIDC federation choice. Three workflows, single environment per PROJECT.md §II.2.11.
- **Acceptance Criteria (post-M1.4 baseline):**
  - [ ] `ci.yml` runs on every PR; fails on lint or test errors; posts Bicep `what-if` diff as a PR comment when `infra/**` changed
  - [ ] `cd-infra.yml` triggers only on push to `main` with paths under `infra/**`; deploys via OIDC; reuses the federated identity from M1.4
  - [ ] `cd-app.yml` polished beyond M1.4 MVP: traffic-shifting smoke gate (deploy revision, health-check, then shift 100%), revision retention policy, build cache for faster rebuilds
  - [ ] App Insights deployment annotation created on every successful deploy (release event with commit SHA)
  - [ ] Status badges in README for all three workflows; replace M1.1 placeholder badge
  - [ ] All three workflows green on `main` after a representative test (one no-op infra commit, one no-op app commit, one PR cycle)
  - [ ] Branch protection rule on `main`: PRs require `ci.yml` to pass before merge
  - [ ] Rollback procedure documented in README (`az containerapp revision activate ...`, Foundry agent rollback note)
  - [ ] **ADR 0002** written: "OIDC federation for Azure access from GitHub Actions" — captures the auth model decision, the Entra app + federated credential setup, and the rationale (no long-lived secrets in the repo). Decision was effectively made in M1.4; M1.5 codifies it.
- **Closed:**
- **Notes:** M1.4 borrows `cd-app.yml` in MVP form (build + push + container-app update + basic smoke). M1.5 hardens it.

### M1.6 — Foundry project + Azure OpenAI provisioned
- **Status:** 🔵
- **Depends on:** M1.3
- **Description:** Provision Microsoft Foundry project, Foundry Agent Service enabled, two Azure OpenAI model deployments (`gpt-4o` and `text-embedding-3-large`) accessible via the Foundry project endpoint. Container App uses managed identity with appropriate Foundry/OpenAI roles. Adds `foundry.bicep`. Per PROJECT.md §III.7, hosted-agent resources must support clean nightly teardown.
- **Acceptance Criteria:**
  - [ ] `infra/modules/foundry.bicep` provisions Foundry project + Agent Service
  - [ ] Two model deployments exist and are reachable via the Foundry project endpoint
  - [ ] Service principal from M1.5 has `Azure AI Project Manager` role
  - [ ] Container App managed identity has `Cognitive Services OpenAI User` (or Foundry equivalent)
  - [ ] A `/test/foundry` dev-only endpoint (behind a flag) confirms a successful chat completion via `FoundryChatClient`
  - [ ] No API keys in code or env — managed identity only for app; OIDC for CI
  - [ ] Tokens-per-minute quotas documented in README troubleshooting
  - [ ] **`azd down --force --purge` cleanly removes Foundry project + hosted agents** (no orphans, no soft-delete blockers preventing same-name recreation next day)
  - [ ] **`azd up` cold-start including Foundry provisioning completes in ≤10 minutes total**
- **Closed:**
- **Notes:**

---

## Milestone 2 — Agents + RAG (Week 2)

**Goal:** Single MAF agent over a synthetic corpus with citations, served through Streamlit.

### M2.1 — Synthetic dataset
- **Status:** 🔵
- **Depends on:** M1.1
- **Description:** Create a synthetic corpus of ~30 short documents in `data/`: project briefs, vendor profiles, compliance standards, PO templates. Markdown files. Realistic but obviously fictional (no real companies, no real people).
- **Acceptance Criteria:**
  - [ ] At least 8 project briefs, 8 vendor profiles, 8 compliance standards, 6 PO templates
  - [ ] Each doc has YAML frontmatter with `id`, `type`, `title`, `tags`
  - [ ] No real company or person names
  - [ ] Docs cross-reference each other (e.g., a brief mentions a vendor that exists)
  - [ ] `data/README.md` explains the corpus
- **Closed:**
- **Notes:**

### M2.2 — Foundry IQ + Blob via Bicep
- **Status:** 🔵
- **Depends on:** M1.6
- **Description:** Bicep additions for Azure Blob containers (`documents`, `chunks`) and Foundry IQ knowledge source pointing at the Blob. Foundry IQ provisions and manages the underlying Azure AI Search index.
- **Acceptance Criteria:**
  - [ ] `infra/modules/storage.bicep` updated with required containers
  - [ ] `infra/modules/foundry.bicep` updated to register a Foundry IQ knowledge source over the Blob
  - [ ] Blob `documents` accessible via managed identity from Container App
  - [ ] Foundry IQ search endpoint reachable from FastAPI
  - [ ] Outputs piped to Container App env vars
- **Closed:**
- **Notes:**

### M2.3 — Document ingestion pipeline
- **Status:** 🔵
- **Depends on:** M2.1, M2.2
- **Description:** A `backend/rag/ingest.py` script: walks `data/`, uploads to Blob, registers/refreshes the Foundry IQ knowledge source. Foundry IQ handles chunking + embedding + indexing. Per PROJECT.md §III.7, ingestion must run automatically on every cold-start (since AI Search is deleted nightly).
- **Acceptance Criteria:**
  - [ ] CLI: `python -m backend.rag.ingest --source data/ --knowledge-source procurement-v1`
  - [ ] Idempotent: re-running with no doc changes triggers a no-op (or a delta refresh) at Foundry IQ
  - [ ] Uploaded blobs include metadata: `doc_id`, `type`, `title`, `tags`
  - [ ] Logs total docs uploaded, indexing status, dollars at current pricing (best-effort estimate)
  - [ ] **Cold-start integration:** ingestion runs automatically as part of `make azd-up`, either as a Container App job or as a post-deploy step in the lifecycle Makefile target. Total ingestion time logged.
  - [ ] **Cold-ingest completes in ≤4 minutes** for the full ~30-doc corpus (target consistent with §III.7 cold-start budget)
- **Closed:**
- **Notes:**

### M2.4 — RAG query endpoint with citations
- **Status:** 🔵
- **Depends on:** M2.3
- **Description:** `POST /rag/query` endpoint that calls Foundry IQ + returns top-K chunks with citation metadata.
- **Acceptance Criteria:**
  - [ ] Endpoint accepts `{query, top_k, filters}`
  - [ ] Returns `{chunks: [{doc_id, title, text, score}], query_time_ms}`
  - [ ] Hybrid search (keyword + vector) used; semantic ranker on
  - [ ] Filterable by `type` and `tags`
  - [ ] Unit tests cover empty results, filter, top_k
- **Closed:**
- **Notes:**

### M2.5 — PM Agent (first MAF agent)
- **Status:** 🔵
- **Depends on:** M2.4, M1.6
- **Description:** A MAF `Agent` using `FoundryChatClient` with one capability: `gather_project_context`. Uses Foundry IQ to retrieve project + vendor context for a given project name. Returns structured output `{summary, vendors_considered, citations[], confidence}`.
- **Acceptance Criteria:**
  - [ ] `backend/agents/pm_agent.py` defines the MAF agent
  - [ ] System prompt is in a separate `prompts/pm_agent.md` file (not inline)
  - [ ] Output validated against a Pydantic schema
  - [ ] Returns at least 2 citations from the corpus on the test query
  - [ ] Self-reported `confidence: float` field on output
  - [ ] Unit test: given a known project, asserts citations include the correct doc
  - [ ] Integration test: agent runs against a deployed Foundry endpoint (or skipped with marker if no creds)
- **Closed:**
- **Notes:**

### M2.6 — Streamlit UI (single-agent)
- **Status:** 🔵
- **Depends on:** M2.5
- **Description:** Minimal Streamlit chat UI that calls the API, displays the agent response, and shows citations + an expandable "agent trace" panel.
- **Acceptance Criteria:**
  - [ ] `frontend/streamlit_app.py` runs with `streamlit run`
  - [ ] Chat history persists in session state
  - [ ] Citations render as clickable sections showing the chunk text
  - [ ] "Agent trace" expander shows the prompt, tool calls (none yet), and raw output
  - [ ] Deployed to Azure Container Apps (or App Service) via Bicep + CD workflow
- **Closed:**
- **Notes:**

### M2.7 — RAG eval harness
- **Status:** 🔵
- **Depends on:** M2.3
- **Description:** A pytest suite using ragas (or simple precision/recall) on a labelled test set of ~15 query→expected-doc pairs.
- **Acceptance Criteria:**
  - [ ] `tests/evals/rag_test_set.json` with 15+ labelled pairs
  - [ ] `tests/evals/test_rag.py` runs the suite, asserts retrieval precision ≥ 0.7
  - [ ] Eval results written to `tests/evals/results/` as JSON with timestamp
  - [ ] Documented in README: "How to run RAG evals"
- **Closed:**
- **Notes:**

---

## Milestone 3 — Multi-agent + Workflows + Guardrails + Memory (Week 3)

**Goal:** End-to-end PO flow with all agents, Foundry Workflows, guardrails, and memory.

### M3.1 — Purchaser + Compliance agents
- **Status:** 🔵
- **Depends on:** M2.5
- **Description:** Add `purchaser_agent.py` and `compliance_agent.py` following the PM Agent pattern (MAF `Agent` + `FoundryChatClient`). Each has its own prompt, output schema, and unit tests.
- **Acceptance Criteria:**
  - [ ] Both agents implemented with separate prompt files
  - [ ] Pydantic output schemas
  - [ ] Each has at least 2 unit tests (golden input/output)
  - [ ] Self-reported `confidence: float` field on every output
- **Closed:**
- **Notes:**

### M3.2 — Cosmos DB + Foundry Memory
- **Status:** 🔵
- **Depends on:** M1.3
- **Description:** Bicep for Cosmos DB serverless with containers `po_state` and `audit`. Enable Foundry Memory (preview) on the Foundry project for agent memory (per-buyer scope via custom userId header). `backend/memory/` provides typed Python clients for Cosmos; Foundry Memory accessed via MAF native APIs.
- **Acceptance Criteria:**
  - [ ] Cosmos resource provisioned via Bicep
  - [ ] `POStateStore` and `AuditStore` classes with typed methods
  - [ ] Foundry Memory enabled on the project; smoke-test demonstrates an agent recalling a stored fact across two invocations
  - [ ] Managed identity access (no keys) for Cosmos
  - [ ] Custom userId scoping documented; Foundry Memory CRUD verified
- **Closed:**
- **Notes:**

### M3.3 — Foundry Toolbox: four MCP-native tools
- **Status:** 🔵
- **Depends on:** M1.4
- **Description:** Implement four read-only tools as a small FastAPI sidecar registered with Foundry Toolbox, exposing a single MCP-compatible endpoint: `template_lookup`, `mock_erp`, `standards_engine`, `buyer_history`.
- **Acceptance Criteria:**
  - [ ] Tools live under `backend/tools/` and run as a sidecar Container App
  - [ ] Registered with Foundry Toolbox; visible in Foundry portal Tools view
  - [ ] No side effects (idempotent, read-only)
  - [ ] OpenAPI schema generated and saved to `docs/tools-openapi.json`
  - [ ] Each tool has unit tests
  - [ ] PM/Purchaser/Compliance agents can call tools through Foundry Toolbox by name
- **Closed:**
- **Notes:**

### M3.4 — Guardrails layer
- **Status:** 🔵
- **Depends on:** M3.1
- **Description:** Implement five guardrails per PROJECT.md §II.2.3, applied at API boundary and at every agent→tool boundary where Foundry's built-in protection is insufficient.
- **Acceptance Criteria:**
  - [ ] `backend/guardrails/` with one module per check (schema, injection, policy, confidence)
  - [ ] Pydantic schema enforcement on all API inputs/outputs
  - [ ] Injection check at API edge: heuristic + LLM-as-judge fallback (Foundry XPIA covers agent-internal)
  - [ ] Policy validator with at least 3 rules (PO threshold, vendor blocklist, category restriction)
  - [ ] Confidence threshold: if any agent reports < 0.7, escalate to human-in-the-loop via Workflow checkpoint
  - [ ] Each guardrail emits a telemetry event on hit (App Insights + Foundry observability)
  - [ ] Unit tests for each guardrail
- **Closed:**
- **Notes:**

### M3.5 — POCreationWorkflow (Foundry Workflows)
- **Status:** 🔵
- **Depends on:** M3.1, M3.2, M3.3, M3.4
- **Description:** Foundry Workflow coordinating the PO creation flow per PROJECT.md §II.3. Defined in `backend/workflows/po_creation.py` using MAF Workflow APIs. Deployed to Foundry Agent Service.
- **Acceptance Criteria:**
  - [ ] `backend/workflows/po_creation.py` implements the flow with executors and edges
  - [ ] Uses Workflow checkpoints for human-in-the-loop wait (max 5 min in demo, configurable)
  - [ ] Workflow state inspectable via Foundry portal
  - [ ] Writes audit entries via Task Agent
  - [ ] Integration test: triggers workflow, asserts terminal state and audit log
- **Closed:**
- **Notes:**

### M3.6 — ComplianceReviewWorkflow
- **Status:** 🔵
- **Depends on:** M3.5
- **Description:** Second Foundry Workflow triggered when a submitted PO crosses the policy threshold. Runs Compliance Agent against `standards_engine` tool + Foundry IQ, writes outcome.
- **Acceptance Criteria:**
  - [ ] Triggered automatically by `POCreationWorkflow` for qualifying POs
  - [ ] Runs Compliance Agent against `standards_engine` tool + Foundry IQ
  - [ ] Writes `compliance_outcome` (approve/reject + rationale + citations) to Cosmos
  - [ ] Integration test for both branches (approve, reject)
- **Closed:**
- **Notes:**

### M3.7 — Audit log + read API
- **Status:** 🔵
- **Depends on:** M3.5
- **Description:** Audit entries written by Task Agent for every agent action, tool call, workflow checkpoint, and guardrail hit. Read endpoint `GET /po/{id}/audit`.
- **Acceptance Criteria:**
  - [ ] Audit schema: `{ts, po_id, actor, action, payload_hash, telemetry_id}`
  - [ ] Stored in Cosmos `audit` container
  - [ ] `GET /po/{id}/audit` returns ordered audit trail
  - [ ] Streamlit shows audit trail in a separate tab
- **Closed:**
- **Notes:**

### M3.8 — End-to-end happy-path test
- **Status:** 🔵
- **Depends on:** M3.6, M3.7
- **Description:** A pytest integration test that drives the full PO creation flow against a deployed environment (Foundry Workflow + agents + tools + Cosmos).
- **Acceptance Criteria:**
  - [ ] Test creates a PO, polls until terminal, asserts audit trail completeness
  - [ ] Runs in CI against an ephemeral env (or skipped with marker if no creds)
  - [ ] Documented in README under "Running E2E tests"
- **Closed:**
- **Notes:**

---

## Milestone 4 — Polish + Demo (Week 4)

**Goal:** Demo-ready repo: dashboards, evals, ADRs, recorded walkthrough.

### M4.1 — Foundry Observability + App Insights dashboards
- **Status:** 🔵
- **Depends on:** M3.5
- **Description:** Saved KQL queries + an Azure Workbook for: latency per agent, token cost per workflow run, guardrail-hit rate, end-to-end success rate. Foundry Control Plane bookmarks for live agent + workflow traces.
- **Acceptance Criteria:**
  - [ ] Workbook JSON committed to `infra/workbooks/`
  - [ ] Workbook deployed via Bicep
  - [ ] Foundry Control Plane bookmarks listed in README
  - [ ] Screenshots in README
- **Closed:**
- **Notes:**

### M4.2 — Custom AI telemetry helpers
- **Status:** 🔵
- **Depends on:** M1.6
- **Description:** Helper module wrapping non-Foundry LLM calls (e.g., guardrail LLM-as-judge) to emit structured telemetry: `prompt`, `completion`, `tokens_in`, `tokens_out`, `cost_usd`, `latency_ms`, `agent`, `workflow_id`. Foundry-internal calls already emit telemetry natively; this module fills the non-Foundry gap.
- **Acceptance Criteria:**
  - [ ] `backend/telemetry/ai_logger.py` with a context-managed wrapper
  - [ ] Adopted by guardrail LLM-as-judge and any non-Foundry LLM call
  - [ ] Cost calculation against current Azure OpenAI pricing (configurable table)
  - [ ] At least one KQL query in the dashboard uses these events
- **Closed:**
- **Notes:**

### M4.3 — Eval suite expansion (incl. Foundry agent evals)
- **Status:** 🔵
- **Depends on:** M2.7, M3.8
- **Description:** Expand evals to cover (a) RAG retrieval, (b) per-agent output quality (golden cases), (c) end-to-end happy and unhappy paths, (d) Foundry-managed agent evaluation on at least one agent.
- **Acceptance Criteria:**
  - [ ] At least 30 total test cases across categories (a)–(c)
  - [ ] `make eval` runs the full local suite with a summary table
  - [ ] Foundry agent eval configured for at least one agent (PM Agent), passing ≥ 0.7 task success
  - [ ] Pass thresholds documented and enforced
- **Closed:**
- **Notes:**

### M4.4 — README polish + diagrams
- **Status:** 🔵
- **Depends on:** M3.8
- **Description:** Polish README with hero diagram, quickstart, architecture summary, demo gif/video, badges, and a "What this demonstrates" section mapping features to JD keywords.
- **Acceptance Criteria:**
  - [ ] Mermaid architecture diagram embedded
  - [ ] Quickstart works for a fresh contributor in <15 minutes
  - [ ] Demo gif (or video link) embedded
  - [ ] CI status, license, Python version badges
  - [ ] Section mapping features to JD keywords (MAF, Foundry, Workflows, IQ, Toolbox, MCP, guardrails, etc.)
- **Closed:**
- **Notes:**

### M4.5 — Demo script + recorded walkthrough
- **Status:** 🔵
- **Depends on:** M4.4
- **Description:** A 5–7 minute recorded walkthrough following `docs/demo-script.md`. Posted unlisted on YouTube or Loom.
- **Acceptance Criteria:**
  - [ ] `docs/demo-script.md` written: intro, 3 scenarios (happy path, compliance reject, guardrail block), wrap
  - [ ] Recorded video linked in README
  - [ ] No real names, real client info, or any employer-specific material visible
- **Closed:**
- **Notes:**

### M4.6 — ADR series
- **Status:** 🔵
- **Depends on:** M1.2
- **Description:** Architecture Decision Records for the major calls. ADR 0001 already in M1.2; this story closes the rest.
- **Acceptance Criteria:** at least 5 ADRs total:
  - [ ] 0001 — Foundry + MAF, not LangGraph standalone (from M1.2)
  - [ ] 0002 — Streamlit not React
  - [ ] 0003 — Bicep not Terraform
  - [ ] 0004 — Foundry Memory + Cosmos split (memory vs domain state)
  - [ ] 0005 — Foundry IQ for RAG
  - [ ] Each follows the standard template (Context, Decision, Consequences, Alternatives Considered)
- **Closed:**
- **Notes:**

### M4.7 — Production posture paper-design
- **Status:** 🔵
- **Depends on:** M3.6
- **Description:** `docs/production-posture.md` — paper design only. Documents what would change to take this from demo to production: hub-spoke, zone-redundant Foundry, Defender for Cloud, multi-region, real RBAC/Entra, real ERP integration, durable batch via Durable Functions, Microsoft 365 publishing, etc.
- **Acceptance Criteria:**
  - [ ] Component-by-component "demo vs production" table
  - [ ] Effort T-shirt sizing per upgrade
  - [ ] Identified risks and pre-reqs
  - [ ] No code — design doc only
- **Closed:**
- **Notes:**

### M4.7.5 — Interview walkthrough runbook
- **Status:** 🔵
- **Depends on:** M1.3.5, M4.5
- **Description:** `docs/walkthrough.md` — the timed cold-start runbook for an interview demo. Per PROJECT.md §III.7, the runbook is the operational counterpart to the demo script: how to bring the stack up reliably under time pressure.
- **Acceptance Criteria:**
  - [ ] `docs/walkthrough.md` written with sections: Pre-flight (T-15 min), Cold-start (T-10 min), Smoke verification (T-5 min), During the call (links to demo-script.md), Teardown (post-call)
  - [ ] Each section has a checklist with explicit commands (`make azd-up`, expected output, verification curl, etc.)
  - [ ] Recovery procedures documented for the 3 most likely failures: quota error, OIDC auth failure, partial Foundry provisioning
  - [ ] Timing budget per phase documented and verified against `tests/cold-start-history.csv`
  - [ ] No real names, no employer-specific material, no actual interview specifics
- **Closed:**
- **Notes:**

---

## Change Log

- **v4.3 (2026-05-03)** — Owner-driven scope rebalance for M1.4/M1.5. M1.4 expanded to absorb the minimum-viable CD pipeline (first `cd-app.yml`, OIDC federation bootstrap script, Container Apps Bicep module). M1.5 trimmed to "polish & full coverage" (ci.yml, cd-infra.yml, branch protection, deployment annotations, ADR 0002 for OIDC). Trade-off: M1.4 takes ~2x longer but Phase 1+Phase 2 cold-start orchestration becomes real after closure rather than diagrammed-only. Story count unchanged at 30.
- **v4.2 (2026-05-03)** — M1.3.5 closed 🟢. Status snapshot updated (4/30, 13%); M1 milestone now 4/7 (57%). First real Azure deploy verified end-to-end: cold-start 186 s, idempotent re-run 33 s, teardown clean with KV purged. Cost meter back to $0/day idle. M1.4 AC needs to fold the deferred `/health` smoke test from M1.3.5.
- **v4.1 (2026-05-02)** — M1.3 closed 🟢. Status snapshot updated (3/30, 10%).
- **v4.0 (2026-05-02)** — Aligned to PROJECT.md v3.2. Story count 28 → 30: added M1.3.5 (lifecycle scripts) and M4.7.5 (interview walkthrough runbook).
- **v3.2 (2026-05-02)** — M1.2 closed 🟢. Status snapshot updated (2/28, 7%). ADR 0001 delivered + README v3.1 alignment gap-fix completed.
- **v3.1 (2026-05-02)** — Scrubbed residual employer reference in M4.5 AC.
- **v3.0 (2026-05-02)** — Realigned to PROJECT.md v3.0 (Azure-native architecture). M1.6 changed from "Azure OpenAI provisioned" to "Foundry project + Azure OpenAI provisioned" — adds `foundry.bicep`, Foundry Agent Service, Project Manager role assignment. M2.2/M2.3/M2.4 reframed around Foundry IQ instead of raw Azure AI Search. M2.5/M3.1 use MAF + FoundryChatClient instead of LangGraph. M3.2 adds Foundry Memory alongside Cosmos. M3.3 uses Foundry Toolbox sidecar registration instead of standalone HTTP tools. M3.5/M3.6 use Foundry Workflows instead of Azure Durable Functions (Durable Functions deferred to M4.7 production-posture). M4.3 adds Foundry-managed agent evals. M4.7 changed from "Foundry migration paper-design" (no longer needed — we *are* on Foundry) to "production-posture paper-design". Backlog story count unchanged at 28; ~12 stories rewritten in shape, none added or removed.
- **v2.1 (2026-05-02)** — M1.1 closed 🟢. Status snapshot updated (1/28). Three deviations approved.
- **v2.0 (2026-05-02)** — Two-document model: PROJECT.md + BACKLOG.md.
- **v1.1 (2026-05-02)** — Single-environment CD model.
- **v1.0 (2026-05-02)** — Initial backlog.
