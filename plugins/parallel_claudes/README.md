# Parallel Claudes

Orchestrate multiple Claude instances for higher quality code generation through parallel execution, independent perspectives, and specialized reviews.

## Installation

Add this plugin directory to your Claude Code settings, then start using the commands:
```
/parallel_claudes:parallel_generation your task here
```

## What it Does

- Spawns multiple Claude instances in parallel for independent code generation
- Applies confidence voting and synthesis to merge solutions
- Provides specialized role-based review from five expert perspectives (security, performance, edge cases, maintainability, testing)
- Uses formalized agent definitions for consistent, expert-level analysis

## How it Works

1. You provide a task or code to review
2. Multiple Claude subagents execute independently in parallel
3. Solutions are compared for agreement level (strong, partial, or disagreement)
4. Results are synthesized through voting, debate, or user choice

## Why Parallel Claudes?

- **No external dependencies**: Unlike council (which requires Codex CLI), this plugin works with Claude alone
- **Prevents context overload**: Fresh Claude instances avoid "cutting corners" from accumulated context
- **Majority voting**: 3+ independent perspectives catch blind spots better than a single run
- **Specialized expertise**: Role-based reviews provide focused, expert-level feedback

## Specialized Agents

This plugin includes formalized agent definitions in the `agents/` directory. Each agent is an expert in a specific domain:

| Agent | File | Focus |
|-------|------|-------|
| Security | `agents/security_agent.md` | Vulnerabilities, OWASP Top 10, injection attacks |
| Performance | `agents/performance_agent.md` | Algorithmic complexity, memory, caching |
| Edge Cases | `agents/edge_cases_agent.md` | Null handling, boundaries, error paths |
| Maintainability | `agents/maintainability_agent.md` | SOLID principles, coupling, clarity |
| Testing | `agents/testing_agent.md` | Coverage gaps, testability, mocking |

### Using Specialized Agents

**In role_based_review** (default behavior):
```
/parallel_claudes:role_based_review src/api/auth.ts
# Uses all 5 specialized agents automatically

/parallel_claudes:role_based_review --roles security,testing src/api/auth.ts
# Uses only security and testing agents
```

**In parallel_generation** (new `--roles` flag):
```
/parallel_claudes:parallel_generation --roles security,performance implement rate limiting
# Spawns agents with security-first and performance-first perspectives
```

**In generation_and_review** (new `--reviewer-roles` flag):
```
/parallel_claudes:generation_and_review --reviewer-roles security,testing implement auth
# Uses specialized reviewers instead of generic ones
```

**In swarm** (per-task agent assignment):
```
/parallel_claudes:swarm add user auth with security review
# Task breakdown can assign security, testing agents to specific tasks
```

See `agents/README.md` for full documentation.

## Commands

### `/parallel_claudes:parallel_generation`

Run multiple Claude instances in parallel on the same task, then apply confidence voting with synthesis fallback.

**Use when:** You want multiple independent solutions to compare and merge.

**How it works:**
1. Parses task and configuration flags
2. Spawns N Claude subagents in parallel (default: 3)
3. Each instance generates a solution independently
4. Compares solutions for agreement level (STRONG_AGREE, PARTIAL_AGREE, DISAGREE)
5. Outputs consensus or synthesized result based on conflict resolution mode

**Flags:**
- `--count N` / `-n N`: Number of instances, 2-7 (default: 3)
- `--model <model>`: Model for all instances — `sonnet`, `opus`, `haiku` (default: sonnet)
- `--conflict <mode>`: `majority_vote` (default), `show_all`, `debate`
- `--context <mode>`: `compressed` (default), `full`
- `--roles <list>`: Specialized agent perspectives (e.g., `security,performance`) — overrides `--count`

**Example:**
```
/parallel_claudes:parallel_generation implement a rate limiter with sliding window
/parallel_claudes:parallel_generation -n 2 --conflict show_all add user authentication
```

---

### `/parallel_claudes:generation_and_review`

One Claude generates a solution, then multiple Claudes review it in parallel for faster, more thorough feedback.

**Use when:** You want thorough code review without sequential bottleneck.

**How it works:**
1. Claude generates initial solution (or uses provided code)
2. Spawns N reviewer subagents in parallel (default: 3)
3. Each reviewer independently analyzes for bugs, security, performance, edge cases
4. Aggregates reviews—issues found by multiple reviewers marked as high-confidence
5. Outputs consolidated review with proposed fixes

**Flags:**
- `--count N` / `-n N`: Number of reviewers, 1-7 (default: 3)
- `--model <model>`: Model — `sonnet`, `opus`, `haiku` (default: sonnet)
- `--conflict <mode>`: `majority_vote` (default), `show_all`, `debate`
- `--context <mode>`: `compressed` (default), `full`
- `--reviewer-roles <list>`: Specialized reviewer agents (e.g., `security,testing`) — overrides `--count`

**Example:**
```
/parallel_claudes:generation_and_review implement JWT authentication
/parallel_claudes:generation_and_review src/utils/validators.ts
/parallel_claudes:generation_and_review -n 5 --conflict show_all the payment module
```

---

### `/parallel_claudes:role_based_review`

Specialized reviewer Claudes, each focused on a specific aspect of code quality. Get expert-level feedback from multiple perspectives simultaneously.

**Use when:** You want deep, focused analysis from different expert viewpoints.

**Available roles:**
| Role | Focus |
|------|-------|
| `security` | Vulnerabilities, injection, auth issues, OWASP Top 10 |
| `performance` | Algorithmic complexity, memory, caching, efficiency |
| `edge_cases` | Null handling, boundaries, error paths, race conditions |
| `maintainability` | SOLID principles, coupling, naming, abstractions |
| `testing` | Coverage gaps, testability, mocking needs |

**How it works:**
1. Gathers code to review (files or snippets)
2. Spawns one subagent per selected role (default: all 5)
3. Each role-agent focuses ONLY on their specialty
4. Aggregates findings by severity (critical/warning/suggestion)
5. Outputs structured review organized by role with verdicts

**Flags:**
- `--roles <list>`: Comma-separated roles — `security`, `performance`, `edge_cases`, `maintainability`, `testing` (default: all 5)
- `--context <mode>`: `full` (default), `compressed` — uses full context by default so reviewers understand intent

**Example:**
```
/parallel_claudes:role_based_review src/api/auth.ts
/parallel_claudes:role_based_review --roles security,performance src/payments/
/parallel_claudes:role_based_review --roles edge_cases the new validation logic
```

---

### `/parallel_claudes:swarm`

Break down large tasks into MECE sub-tasks and execute them in parallel waves, applying changes directly to the codebase.

> [!CAUTION]
> **IMMEDIATE EXECUTION** - Unlike other parallel_claudes commands that follow a deliberation-first workflow, **swarm executes changes directly to your codebase** after plan approval. There is no intermediate review step before files are modified.
>
> **Before using swarm:**
> - Ensure your working directory is clean (`git status`)
> - Commit or stash any unsaved work
> - Review the task graph carefully before approving
> - Consider using `--context compressed` for isolated changes
>
> **If something goes wrong:** Use `git diff` to review changes and `git checkout .` to revert.

**Use when:** You have a **larger, complex task** that can be decomposed into independent sub-tasks. Subagents have startup overhead (~5-15 seconds), so swarm is best for tasks where parallel execution saves meaningful time.

**How it works:**
1. Analyzes your task and breaks it into MECE (Mutually Exclusive, Collectively Exhaustive) sub-tasks
2. Identifies dependencies between tasks and groups them into waves
3. Displays the task graph for your approval (including agent types per task)
4. Executes waves in parallel with real-time progress visualization
5. Handles file conflicts (queues agents) and failures (asks you how to proceed)
6. Offers verification (role_based_review or tests) after completion

**Flags:**
- `--count N` / `-n N`: Max concurrent agents per wave, 2-7 (default: 5)
- `--model <model>`: Model for all agents — `sonnet`, `opus`, `haiku` (default: sonnet)
- `--context <mode>`: `compressed` (default), `full`
- `--agent <type>`: Default agent type — `general-purpose` (default), or any specialized agent

**Specialized agents:** Individual tasks can use different agent types (e.g., `feature-dev:code-reviewer` for security review tasks). Claude will suggest specialized agents when appropriate.

**Progress visualization:**
```
## Swarm Progress [12:34:56]

Task 1 [████████████████████] 100% - Complete
Task 2 [████████████░░░░░░░░]  66% - Planning changes
Task 3 [████░░░░░░░░░░░░░░░░]  33% - Reading files
Task 4 [░░░░░░░░░░░░░░░░░░░░]   0% - Queued (waiting on Task 2)

Wave 1: 1/4 complete | Wave 2: Pending
```

**Example:**
```
/parallel_claudes:swarm add user authentication with JWT tokens, user model, auth routes, and tests
/parallel_claudes:swarm -n 3 --model opus rename PaymentService to BillingService across the codebase
/parallel_claudes:swarm --context compressed create unit tests for all utility functions
```

---

## Configuration Options

### Conflict Resolution Modes

| Mode | Behavior |
|------|----------|
| `majority_vote` | If majority agrees, use that solution. Attempt synthesis if no majority. (Default) |
| `show_all` | Present all solutions side-by-side. Claude recommends but user decides. |
| `debate` | Spawn debate rounds for disagreements. Max 2 rounds, then escalate to user. |

### Context Modes

| Mode | Behavior |
|------|----------|
| `compressed` | Agents receive only task + relevant files. Conserves context. (Default for most commands) |
| `full` | Agents receive full conversation context. Better for analysis tasks. |

**Note:** `role_based_review` defaults to `full` because reviewers benefit from understanding the broader context and intent behind the code.

---

## Deliberation → Implementation Workflow

Most commands follow a **deliberation-first** pattern (exception: `swarm` executes after plan approval):

```
/parallel_claudes:parallel_generation "add feature X"
        ↓
[Multiple Claudes generate, compare, reach consensus]
        ↓
"do it" or enter Plan mode
        ↓
[Execute the agreed solution]
```

**Why this pattern works:**
- You see the reasoning before any code changes
- Multiple perspectives validate the approach
- You can reject or modify the consensus before implementation
- Context from deliberation carries forward into implementation

---

## Recommended Workflow: Deliberate → Execute → Verify

For complex features, the ideal path combines all three command types:

```
/parallel_claudes:parallel_generation "design user auth system"
        ↓
[Multiple Claudes propose approaches, reach consensus on design]
        ↓
/parallel_claudes:swarm "implement the agreed auth design"
        ↓
[Parallel agents execute: models, routes, middleware, tests]
        ↓
/parallel_claudes:role_based_review src/auth/
        ↓
[Security, performance, edge case experts review the changes]
```

**Phase 1 - Deliberate** (`parallel_generation`): Get multiple perspectives on *how* to build it. Catches design issues early.

**Phase 2 - Execute** (`swarm`): Parallel implementation of the agreed design. Fast execution with dependency management.

**Phase 3 - Verify** (`role_based_review`): Expert review from multiple angles. Catches implementation issues before commit.

This workflow gives you the best of all worlds: thoughtful design, efficient execution, and thorough verification.

---

## Comparison with Council Plugin

| Feature | Council | Parallel Claudes |
|---------|---------|------------------|
| Models used | Claude + Codex | Claude only |
| External dependency | Requires Codex CLI | None |
| Default instances | 2 (Claude vs Codex) | 3 (for majority voting) |
| Configurable count | No | Yes (`--count N`) |
| Role-based review | No | Yes |
| Context modes | N/A | Full or Compressed |

Use **Council** when you want Claude + Codex diversity.
Use **Parallel Claudes** when you want multiple independent Claude perspectives without external dependencies.

---

## Input Validation

All commands validate flags before execution:

| Flag | Valid Values | Default |
|------|-------------|---------|
| `--count` | 1-7 (review), 2-7 (generation/swarm) | 3 (5 for swarm) |
| `--model` | sonnet, opus, haiku | sonnet |
| `--conflict` | majority_vote, show_all, debate | majority_vote |
| `--context` | compressed, full | compressed |
| `--roles` | security, performance, edge_cases, maintainability, testing | all 5 |
| `--agent` | general-purpose, or any specialized agent type | general-purpose |

**Behavior:**
- Invalid values trigger a warning and fall back to defaults
- Out-of-range `--count` is clamped (min 1 for review commands, min 2 for generation/swarm, max 7 for cost control)
- Invalid role names are skipped with a warning

---

## Token Efficiency

All commands include built-in efficiency rules:
- Skip parallel execution for trivial tasks (<20 lines, no complexity)
- Early termination on strong agreement
- Deduplicate findings across reviewers
- Focus on severity (critical first, suggestions last)
- Parallel Task tool calls (not sequential)
