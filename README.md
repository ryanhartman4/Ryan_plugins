# Ryan's Claude Plugins

Personal plugin marketplace for Claude Code.

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
