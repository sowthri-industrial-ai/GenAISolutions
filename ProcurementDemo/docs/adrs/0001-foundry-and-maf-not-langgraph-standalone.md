# ADR 0001: Microsoft Foundry + Microsoft Agent Framework, not LangGraph standalone

## Status

Accepted

## Date

2026-05-02

## Context

This project is a portfolio-grade demonstration of an enterprise agentic procurement workflow on Microsoft Azure (PROJECT.md §I.1). The architecture splits work between LLM agents (PM, Purchaser, Compliance) and non-LLM agents (Interface, Task), coordinated by two long-running graph orchestrations (`POCreationWorkflow`, `ComplianceReviewWorkflow`) with human-in-the-loop checkpoints, RAG over a synthetic corpus, an MCP-style read-only tool layer, agent memory, and end-to-end observability (PROJECT.md §I.4, §II.1).

We need to pick the agent SDK, the orchestrator, and the hosted runtime now, before any agent or workflow code is written (M2.5 onwards). The choice has to outlive the four-week build and stay credible for a portfolio reviewer who knows the current Microsoft agentic stack.

The platform landscape shifted in April 2026. **Microsoft Agent Framework (MAF) v1.0 went GA on April 3, 2026**, merging Semantic Kernel and AutoGen into a single supported SDK with first-party Foundry integration. **Foundry Agent Service hosted-agent billing began on April 22, 2026** (per vCPU/GiB-hour for the runtime, model inference billed separately). **Foundry Memory** — the per-agent persistent memory feature MAF agents bind to natively — moves to paid GA on **June 1, 2026**. Around the same window, Foundry consolidated three pieces we would otherwise have to assemble ourselves: Foundry Workflows (graph orchestration with checkpointing and multi-agent patterns), Foundry IQ (managed agentic RAG over Azure AI Search with permission-aware retrieval), and Foundry Toolbox (a single MCP-compatible endpoint with built-in auth, tracing, and Microsoft Entra Agent Identity).

The alternative is to build the same surface ourselves on Container Apps with LangGraph and a hand-rolled tool/RAG/memory layer. That is a defensible engineering choice but a much weaker portfolio signal in 2026: it shows pattern fluency without showing fluency in the platform Microsoft now expects enterprise agents to run on.

## Decision

We adopt the Microsoft-native agentic stack end-to-end:

- **Agent SDK:** Microsoft Agent Framework v1.0 (Python). All three LLM agents (PM, Purchaser, Compliance) are MAF `Agent` instances using `FoundryChatClient` for model access. Non-LLM agents (Interface, Task) stay as plain Python — MAF is not used where there is no LLM call.
- **Orchestrator:** Foundry Workflows. Both `POCreationWorkflow` and `ComplianceReviewWorkflow` are defined in `backend/workflows/` using MAF Workflow APIs (executors + edges + conditional routing). Human-in-the-loop is implemented with Workflow checkpoints, not custom timer logic. Azure Durable Functions is **not** the orchestrator; it is reserved for non-LLM batch operations and is currently deferred (PROJECT.md §II.2.4).
- **Hosted runtime:** Foundry Agent Service. LLM agents and Workflows run as managed hosted agents; the FastAPI layer in Container Apps invokes them through the Foundry SDK. This gives us managed scaling, Microsoft Entra Agent Identity per agent, and native traces in the Foundry Control Plane.
- **Tools, RAG, memory, observability:** Foundry Toolbox (MCP-native tools), Foundry IQ (RAG), Foundry Memory (per-buyer agent memory, with Cosmos DB owning domain state), and Foundry Control Plane Observability exported into Application Insights for unified dashboards.
- **LangGraph:** retained as a documented interop fallback only. Foundry Agent Service supports LangGraph as a hosted-agent runtime, so if MAF blocks the demo we can host a LangGraph agent inside the same Foundry project without abandoning the rest of the stack. We do not write any LangGraph code in this project; the path exists on paper.

## Consequences

**Positive.** The repo demonstrates exactly the stack a 2026 enterprise architect would specify on Azure: MAF for agents, Foundry Workflows for orchestration, Foundry-managed RAG/tools/memory, MCP at the tool boundary, Entra Agent Identity at the trust boundary. Most non-LLM plumbing — agent identity, hosted scaling, tool tracing, RAG indexing, memory persistence, observability — is provided by the platform, which keeps the four-week build focused on the patterns that matter for the demo (multi-agent coordination, guardrails, human-in-the-loop, eval). The LLM/non-LLM agent split (PROJECT.md §II.2.5) maps cleanly onto MAF: LLM agents are MAF `Agent` instances; non-LLM agents stay as plain Python invoked from Workflow nodes or the API layer, with no framework overhead where it adds none. Workflow checkpointing handles the human-in-the-loop pattern in §II.3 without us building a durable timer + external event mechanism by hand.

**Negative — preview surface.** Foundry Memory and several Workflow features are still in preview as of May 2026. Preview features can change shape between SDK releases, and Foundry Memory specifically begins paid billing on June 1, 2026, which means the cost model for an in-flight feature will change mid-build. We mitigate by pinning SDK versions (`PROJECT.md` §III.6 risk #5), capturing working Foundry configurations in subsequent ADRs, and keeping a Cosmos-based memory fallback path so the demo is not blocked if Foundry Memory regresses.

**Negative — Azure lock-in.** Every component except the data corpus and the FastAPI/Streamlit shells is now Azure-native. Porting the agentic core to AWS Bedrock Agents or GCP Vertex AI Agents would be a rewrite, not a port. This is acceptable because the project's purpose is explicitly an *Azure* demonstration (PROJECT.md §I.1), but it is a real cost if the underlying career goal shifts to a multi-cloud posture.

**Negative — MAF API surface still maturing post-GA.** A 1.0 GA on April 3 does not mean the API has fully settled; minor releases through Q2 2026 are likely to refine `Agent`, `FoundryChatClient`, and Workflow APIs. We will hit at least one breaking-ish change during the build. We pin versions in `pyproject.toml` and update deliberately, not on every release.

**Negative — hosted-agent cost.** Foundry hosted-agent billing (per vCPU/GiB-hour from April 22, 2026) is a continuous runtime cost on top of model inference, not a per-call cost. The demo runs on a single environment with `main` always live (PROJECT.md §III.4), which means the meter runs whether anyone is demoing or not. We mitigate via the cost telemetry hook in §III.6 (flag if median per-PO cost exceeds $0.30) and by sizing hosted agents to the smallest viable footprint; production posture would add scale-to-zero policies, which we document but do not implement (M4.7).

## Alternatives Considered

### Vanilla LangGraph standalone on Container Apps

LangGraph is a credible production framework with a clear graph-based mental model, an active community, and good support for the patterns we need (multi-agent supervision, conditional edges, durable state via checkpointers). Hosting it ourselves on Container Apps would give full control and avoid the preview-feature risk above.

We rejected it as the primary stack for two reasons. First, choosing LangGraph in May 2026 — three weeks after MAF GA and four weeks into Foundry hosted-agent billing — sends the wrong signal for a portfolio aimed at Azure architect roles: it reads as "I know agents but not the platform". Second, LangGraph standalone forces us to assemble RAG (Azure AI Search client + index management), tools (FastAPI per tool, hand-rolled tracing), memory (Cosmos client + TTL logic), agent identity (managed identity per Container App), and observability (App Insights wiring per surface) ourselves. The Foundry stack provides those four as managed components; doing them by hand inside a four-week budget means cutting elsewhere. LangGraph remains in this architecture as a documented interop fallback because Foundry Agent Service supports it as a hosted runtime — that gives us an off-ramp without picking it as the on-ramp.

### Microsoft AutoGen (legacy — superseded by MAF)

AutoGen pioneered the conversational multi-agent pattern that MAF inherits, and an AutoGen-based demo would still execute. It is the wrong choice in May 2026 because Microsoft has explicitly positioned MAF v1.0 as the merger and successor of both AutoGen and Semantic Kernel; new feature investment, Foundry integration, and long-term support are going to MAF. Building a 2026 portfolio piece on the SDK that was just superseded is a deliberate downgrade, and it would also forfeit the native Foundry Workflow + hosted-agent integration that MAF provides out of the box.

### Semantic Kernel (legacy — superseded by MAF)

Semantic Kernel is the other half of the MAF merger and shares AutoGen's problem: feature investment moved to MAF on April 3, 2026. Semantic Kernel's plugin model and prompt template engine are mature and well-documented, but choosing it now would mean writing against an SDK whose recommended migration path is "rewrite as MAF" — and doing that rewrite later would burn budget the build cannot spare. Semantic Kernel concepts survive inside MAF; the right move is to use MAF directly.

### Custom orchestrator (plain Python + asyncio)

A bespoke orchestrator built on `asyncio` plus a small state machine is technically sufficient for a five-node, two-workflow demo. It would have zero framework lock-in and a tiny dependency surface. We rejected it because the demo's value is showing fluency with named patterns — Workflows, hosted agents, MCP tools, agentic RAG — and a bespoke orchestrator obscures every one of those. It also re-implements the hard parts (durable checkpointing for human-in-the-loop, retry semantics, parallel branch coordination, distributed tracing) badly, in a project where the orchestration is not the point. A custom orchestrator is the right answer for a different problem; not this one.
