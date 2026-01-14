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

## Timeout Behavior

The `run_codex.sh` script includes built-in timeouts for reliability:
- **5-minute check-in**: Prints a status message if Codex is still working
- **10-minute hard timeout**: Terminates Codex and returns partial results if available

If you consistently hit timeouts, consider breaking your task into smaller chunks or simplifying the prompt.

## Deliberation → Implementation Workflow

Council commands are designed as a **deliberation layer**, not direct implementation. The recommended workflow:

```
/council_parallel "add feature X"    # or /council_review
        ↓
[Claude + Codex discuss, compare, reach consensus]
        ↓
"do it" or enter Plan mode
        ↓
[Execute the agreed solution]
```

**Why this pattern works:**
- You see the reasoning before any code changes
- Two models validate the approach (catches blind spots)
- You can reject or modify the consensus before implementation
- The context from council discussion carries forward into implementation

**Note:** Council commands deliberately do not auto-apply changes. This gives you control over what actually gets written to your codebase.

### Future Enhancement

A potential `--apply` flag or follow-up command could streamline this:
```
/council_parallel "add caching to the API"
# ... council deliberates ...
"apply council decision"  # → enters plan mode with pre-filled context
```

## Token Efficiency

All commands include built-in efficiency rules:
- Skip council for trivial tasks (<20 lines, no complexity)
- Compress context when sending to Codex
- Early termination on strong agreement
- Incremental context in debate rounds
