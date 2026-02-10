# Ryan's Claude Plugins

Personal plugin marketplace for Claude Code.

## Installation

Install individual plugins directly from GitHub:

```bash
# Install a specific plugin
claude plugin add ryanhartman4/Ryan_plugins/plugins/orient
claude plugin add ryanhartman4/Ryan_plugins/plugins/pass_off
claude plugin add ryanhartman4/Ryan_plugins/plugins/parallel_claudes
claude plugin add ryanhartman4/Ryan_plugins/plugins/council
```

After installing, the plugin's commands are available immediately via `/plugin_name:command_name`.

## Plugins

### orient
Orient yourself to an unfamiliar codebase. Reads documentation, explores project structure with an Explore agent, and checks for project-specific skills — so you start every session with full context.

Commands:
- `/orient:orient` - Run the full orientation workflow

### pass_off
Create handoff documents that capture your current work state for session transitions. Gathers git status, recent changes, in-progress tasks, and generates a timestamped markdown file so the next session (or person) can pick up where you left off.

Commands:
- `/pass_off:pass_off` - Generate a handoff document

---

### parallel_claudes
Orchestrate multiple Claude instances for parallel generation, review, and specialized role-based analysis.

Commands:
- `/parallel_claudes:parallel_generation` - Run multiple Claudes in parallel with confidence voting
- `/parallel_claudes:generation_and_review` - One Claude generates, multiple review in parallel
- `/parallel_claudes:role_based_review` - Specialized reviewers (security, performance, edge cases, etc.)
- `/parallel_claudes:swarm` - Break down complex tasks into MECE (non-overlapping, complete coverage) sub-tasks and execute in parallel waves

> [!NOTE]
> **Agent Teams overlap.** Claude Code now has built-in [agent teams](https://docs.anthropic.com/en/docs/claude-code) with native team creation, shared task lists, and inter-agent messaging. For most parallel execution and coordination use cases, agent teams replace `swarm`. The `parallel_generation` and `role_based_review` commands still offer value for structured multi-perspective deliberation, since agent teams don't have opinionated review workflows built in.

### council
Council of LLMs - orchestrate multiple AI models (Claude + Codex) for higher quality code generation.

Commands:
- `/council:council_parallel` - Run Claude and Codex in parallel with confidence voting
- `/council:council_review` - One model generates, the other reviews with debate
- `/council:council_simple_review` - Quick code review by Codex

> [!NOTE]
> **Largely superseded by agent teams.** The council plugin was built before Claude Code had native multi-agent support. Agent teams now provide the same parallel-generation-and-compare pattern with better coordination primitives (task lists, messaging, file ownership). Council may still be useful if you specifically want **cross-model diversity** (Claude + Codex), but for Claude-only workflows, agent teams or `parallel_claudes` are more capable.
>
> Council also requires Codex CLI to be installed separately.

---

## Choosing a Plugin

| If you want... | Use |
|----------------|-----|
| Get oriented in a new codebase | **orient** |
| Hand off work between sessions | **pass_off** |
| Role-based expert reviews (security, perf, etc.) | **parallel_claudes** (`role_based_review`) |
| Structured multi-Claude deliberation | **parallel_claudes** (`parallel_generation`) |
| Parallel task execution (legacy) | **parallel_claudes** (`swarm`) — consider agent teams instead |
| Cross-model diversity (Claude + Codex) | **council** — consider agent teams instead |

## Design Philosophy

Most commands follow a **deliberation → implementation** pattern:

1. Multiple instances discuss, compare approaches, and reach consensus
2. You review the proposed solution and reasoning
3. You decide whether to implement

This keeps you in control — you see the "why" before any code changes.

**Exception:** `swarm` executes immediately after you approve the task breakdown. Review the breakdown carefully, ensure git state is clean, and consider working on a branch.
