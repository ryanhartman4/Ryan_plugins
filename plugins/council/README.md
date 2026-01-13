# Council of LLMs

Orchestrate multiple AI models (Claude + Codex) for higher quality code generation through parallel execution, cross-review, and debate.

## Commands

### `/council:council_parallel`
Run Claude and Codex in parallel on the same task, then apply confidence voting with synthesis fallback.

**Use when:** You want two independent solutions to compare and merge.

**How it works:**
1. Sends the task to Codex
2. Claude generates its own solution independently
3. Compares solutions for agreement level (STRONG_AGREE, PARTIAL_AGREE, DISAGREE)
4. Outputs consensus or synthesized result

### `/council:council_review`
One model generates code, the other reviews it. Debate and iterate on disagreements.

**Use when:** You want thorough code review with back-and-forth discussion.

**How it works:**
1. Claude generates initial solution (or uses provided code)
2. Codex reviews for bugs, edge cases, performance
3. Claude counter-reviews Codex's feedback
4. Debate rounds resolve disagreements (max 2 rounds)
5. Outputs consolidated review with fixes

### `/council:council_simple_review`
Quick code review by Codex without debate—just get a second opinion.

**Use when:** You want fast feedback without full debate overhead.

**How it works:**
1. Send code or file paths to review
2. Codex analyzes for bugs, security, performance, edge cases
3. Returns structured feedback with severity levels
4. Optional brief Claude note if anything was missed

## Requirements

- Codex CLI installed and authenticated
- The `run_codex.sh` helper script (included in `scripts/`)

## Token Efficiency

All commands include built-in efficiency rules:
- Skip council for trivial tasks (<20 lines, no complexity)
- Compress context when sending to Codex
- Early termination on strong agreement
- Incremental context in debate rounds
