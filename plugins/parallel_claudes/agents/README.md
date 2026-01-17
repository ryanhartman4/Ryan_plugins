# Parallel Claudes Agents

Specialized agent definitions for the parallel_claudes plugin. Each agent is an expert in a specific domain, providing focused analysis without scope creep.

## Available Agents

| Agent | Slug | Focus | Best For |
|-------|------|-------|----------|
| [Security Specialist](security_agent.md) | `security` | Vulnerabilities, OWASP Top 10 | Auth code, API endpoints, data handling |
| [Performance Specialist](performance_agent.md) | `performance` | Complexity, memory, efficiency | Algorithms, database queries, hot paths |
| [Edge Cases Specialist](edge_cases_agent.md) | `edge_cases` | Null handling, boundaries, errors | Input validation, error paths, concurrency |
| [Maintainability Specialist](maintainability_agent.md) | `maintainability` | SOLID, coupling, clarity | Refactoring, architecture, code review |
| [Testing Specialist](testing_agent.md) | `testing` | Coverage, testability, assertions | Test planning, TDD, quality gates |

## Usage

### In role_based_review

```bash
# Use all 5 specialized agents
/parallel_claudes:role_based_review src/api/auth.ts

# Use specific agents only
/parallel_claudes:role_based_review --roles security,performance src/api/auth.ts
```

### In parallel_generation

```bash
# Generate with specialized perspectives
/parallel_claudes:parallel_generation --roles security,performance implement rate limiting
```

### In generation_and_review

```bash
# Use specialized reviewers
/parallel_claudes:generation_and_review --reviewer-roles security,testing implement JWT auth
```

### In swarm

```bash
# Per-task agent assignment in task breakdown
/parallel_claudes:swarm add user auth with security review

# Task breakdown will show:
# - [1] Create User model → Agent: general-purpose
# - [2] Security review → Agent: security (uses security_agent.md)
```

## Agent File Format

Each agent follows this structure:

```markdown
---
name: Human-readable name
slug: short-identifier
description: One-line description
category: reviewer | generator | explorer  # For organization; all current agents are reviewers
verdicts:
  - VERDICT_1
  - VERDICT_2
  - VERDICT_3
---

# Agent Name

## Identity
Who the agent is and their expertise.

## Responsibilities
What they are accountable for.

## Focus Areas
Specific things to examine (detailed list).

## What to Ignore
Explicit exclusions to prevent scope creep.

## Output Format
Structured template for findings.

## Verdict Criteria
Definitions for each verdict level.
```

## How Agents Are Loaded

When a command uses a specialized agent:

1. The command reads the agent file from `${CLAUDE_PLUGIN_ROOT}/agents/{slug}_agent.md`
2. The full content becomes the agent's system instructions
3. Task-specific context (code, files) is appended

```
[Full agent definition content]

---

CODE TO REVIEW:
[code being analyzed]

TASK:
[specific instructions for this run]
```

## Default Behavior

When no `--roles` flag is specified:
- **role_based_review**: Uses all 5 specialized agents
- **parallel_generation**: Uses Anthropic's built-in `general-purpose` agent
- **generation_and_review**: Uses Anthropic's built-in `general-purpose` agent
- **swarm**: Uses `general-purpose` unless per-task override specified

## Adding New Agents

To add a new specialized agent:

1. Create `{slug}_agent.md` following the format above
2. Update this README with the new agent
3. Add the slug to command validation rules (if needed)
4. Update the plugin README.md

## Design Principles

1. **Single Responsibility**: Each agent focuses on ONE domain
2. **Explicit Exclusions**: Agents state what they ignore to prevent overlap
3. **Structured Output**: Severity-based format (CRITICAL/WARNING + domain-specific recommendations)
4. **Clear Verdicts**: Each agent has domain-specific verdict options
