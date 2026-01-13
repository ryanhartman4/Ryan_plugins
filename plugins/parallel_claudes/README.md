# Parallel Claudes

Orchestrate multiple Claude instances for higher quality code generation through parallel execution, independent perspectives, and specialized reviews.

## Why Parallel Claudes?

- **No external dependencies**: Unlike council (which requires Codex CLI), this plugin works with Claude alone
- **Prevents context overload**: Fresh Claude instances avoid "cutting corners" from accumulated context
- **Majority voting**: 3+ independent perspectives catch blind spots better than a single run
- **Specialized expertise**: Role-based reviews provide focused, expert-level feedback

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
- `--context <mode>`: `full` (default), `compressed`

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
- `--context <mode>`: `full` (default), `compressed`

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
- `--context <mode>`: `full` (default), `compressed`

**Example:**
```
/parallel_claudes:role_based_review src/api/auth.ts
/parallel_claudes:role_based_review --roles security,performance src/payments/
/parallel_claudes:role_based_review --roles edge_cases the new validation logic
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
| `full` | Agents receive full conversation context. Best for consistency. (Default) |
| `compressed` | Agents receive only task + relevant files. Best for fresh perspective. |

---

## Deliberation → Implementation Workflow

All commands follow a **deliberation-first** pattern:

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
| `--count` | 2-7 (integer) | 3 |
| `--model` | sonnet, opus, haiku | sonnet |
| `--conflict` | majority_vote, show_all, debate | majority_vote |
| `--context` | full, compressed | full |
| `--roles` | security, performance, edge_cases, maintainability, testing | all 5 |

**Behavior:**
- Invalid values trigger a warning and fall back to defaults
- Out-of-range `--count` is clamped (min 2 for voting, max 7 for cost control)
- Invalid role names are skipped with a warning

---

## Token Efficiency

All commands include built-in efficiency rules:
- Skip parallel execution for trivial tasks (<20 lines, no complexity)
- Early termination on strong agreement
- Deduplicate findings across reviewers
- Focus on severity (critical first, suggestions last)
- Parallel Task tool calls (not sequential)
