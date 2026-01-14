# Ryan's Claude Plugins

Personal plugin marketplace for Claude Code.

## Why Multi-Model Orchestration?

A single AI pass can have blind spots. These plugins address that by bringing multiple perspectives to your code:

- **Catch more issues**: Different models or instances often spot different problems—one might catch a security flaw while another notices a performance bottleneck
- **Reduce overconfidence**: When multiple perspectives agree, you can trust the solution more; when they disagree, you know to look closer
- **Fresh eyes**: Spawning new instances avoids the "context fatigue" where a model starts cutting corners after long conversations

## Deliberation-First Philosophy

These plugins are **thinking tools**, not auto-coders. They follow a deliberation → implementation pattern:

1. Multiple models discuss, compare approaches, and reach consensus
2. You review the proposed solution and reasoning
3. You decide whether to implement (say "do it" or enter plan mode)

This keeps you in control. You see the "why" before any code changes, and you can reject or modify the consensus before anything touches your codebase.

## Choosing a Plugin

| If you want... | Use |
|----------------|-----|
| Claude + Codex diversity (two different models) | **council** |
| Multiple Claude perspectives (no external deps) | **parallel_claudes** |
| Configurable instance count (2-7) | **parallel_claudes** |
| Role-based expert reviews (security, perf, etc.) | **parallel_claudes** |
| Quick second opinion from Codex | **council** (`council_simple_review`) |

**Note**: Council requires Codex CLI installed. Parallel Claudes works with Claude alone.

---

## Plugins

### council
Council of LLMs - orchestrate multiple AI models (Claude + Codex) for higher quality code generation.

Commands:
- `/council:council_parallel` - Run Claude and Codex in parallel with confidence voting
- `/council:council_review` - One model generates, the other reviews with debate
- `/council:council_simple_review` - Quick code review by Codex

### parallel_claudes
Orchestrate multiple Claude instances for parallel generation, review, and specialized role-based analysis.

Commands:
- `/parallel_claudes:parallel_generation` - Run multiple Claudes in parallel with confidence voting
- `/parallel_claudes:generation_and_review` - One Claude generates, multiple review in parallel
- `/parallel_claudes:role_based_review` - Specialized reviewers (security, performance, edge cases, etc.)
