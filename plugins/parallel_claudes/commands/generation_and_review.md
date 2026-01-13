---
description: One Claude generates, then multiple Claudes review in parallel
---

# Generation and Review

One Claude generates a solution, then multiple Claude instances review it in parallel for faster, more thorough feedback.

## Arguments

The user provides either:
- A coding task (Claude generates first, then reviews)
- Existing code or file paths (skip to parallel review)

**Optional flags:**
- `--count N` or `-n N`: Number of parallel reviewers (default: 3)
- `--model <model>`: Model for all instances (sonnet, opus, haiku)
- `--conflict <mode>`: Resolution mode - `majority_vote` (default), `show_all`, `debate`
- `--context <mode>`: Context strategy - `full` (default), `compressed`

## Input Validation

Before executing, validate all flags and show configuration:

### Validation Rules

| Flag | Valid Values | Default | On Invalid |
|------|-------------|---------|------------|
| `--count` | 1-7 (integer) | 3 | Warn and use default |
| `--model` | sonnet, opus, haiku | sonnet | Warn and use default |
| `--conflict` | majority_vote, show_all, debate | majority_vote | Warn and use default |
| `--context` | full, compressed | full | Warn and use default |

**Note:** `--count 1` is valid for reviews (single reviewer) but provides no cross-validation benefit. Recommend 2+ for confidence.

### Error Messages

```
Invalid --count: [value]. Must be 1-7. Using default (3).
Invalid --model: [value]. Valid options: sonnet, opus, haiku. Using default (sonnet).
Invalid --conflict: [value]. Valid options: majority_vote, show_all, debate. Using default (majority_vote).
Invalid --context: [value]. Valid options: full, compressed. Using default (full).
```

### Configuration Display

After parsing, show:
```
## Configuration
- Reviewers: [N]
- Model: [model]
- Conflict resolution: [mode]
- Context: [mode]
```

If any validation warnings occurred, ask: "Continue with these settings?"

## Workflow

### Step 1: Determine Mode

Based on user input:
- **Task provided**: Generate code first, then parallel review
- **Code/files provided**: Skip to parallel review

If reviewing files, read them first. For multiple files, confirm scope before proceeding.

### Step 2: Initial Generation (if task provided)

Generate the initial solution. This becomes the artifact under review.

```
## Initial Generation

### Task
[user's coding task]

### Generated Solution
[complete code solution]

### Design Decisions
- [key decision 1]
- [key decision 2]

---
*Sending to parallel reviewers...*
```

### Step 3: Spawn Parallel Reviewers

Launch N reviewer subagents using the Task tool with `subagent_type=general-purpose`.

**CRITICAL:** Launch all reviewer agents in a SINGLE message with multiple Task tool calls.

Each reviewer receives an independent review prompt:

**If --context full (default):**
```
You are Reviewer [N] in a parallel code review.

CODE TO REVIEW:
[the generated code or provided code]

ORIGINAL TASK:
[what the code is supposed to accomplish]

Review this code thoroughly. Focus on:
1. Bugs and logic errors
2. Security vulnerabilities
3. Performance issues
4. Edge cases not handled
5. Code clarity and maintainability

Be specific with line references. Provide severity levels:
- CRITICAL: Must fix, code won't work correctly
- WARNING: Should fix, potential issues
- SUGGESTION: Nice to have improvements

Output format:
### Critical Issues
[list with line refs]

### Warnings
[list with line refs]

### Suggestions
[list with line refs]

### Overall Assessment
[1-2 sentence summary]
```

**If --context compressed:**
Send only the code and task, no surrounding conversation context.

### Step 4: Aggregate Review Feedback

Collect all reviewer responses and aggregate findings:

1. **Deduplicate**: Group identical issues found by multiple reviewers
2. **Note agreement**: Mark issues found by majority as high-confidence
3. **Preserve unique finds**: Keep issues only one reviewer found (may be valuable)

### Step 5: Apply Conflict Resolution

**If --conflict majority_vote (default):**

```
## Parallel Review Complete

### Code Under Review
[original code]

### High-Confidence Issues (Multiple Reviewers Agreed)
These issues were flagged by 2+ reviewers:

#### Critical
- [ ] **[Issue]** (line X) - Found by [N] reviewers
  - Description: [what's wrong]
  - Fix: [suggested fix]

#### Warnings
- [ ] **[Issue]** (line X) - Found by [N] reviewers
  - Description: [what's wrong]
  - Fix: [suggested fix]

### Additional Findings (Single Reviewer)
These may still be valuable:

- [ ] **[Issue]** (line X) - Reviewer [N]
  - [description and fix]

### Reviewer Agreement Summary
| Issue | R1 | R2 | R3 | Consensus |
|-------|----|----|----|-----------|
| [issue] | ✓ | ✓ | - | 2/3 |

### Proposed Fixes
Based on consensus, here's the improved code:

[code with all high-confidence fixes applied]

---
**Next step:** Say "do it" to apply fixes, or specify which issues to address
```

**If --conflict show_all:**

```
## Parallel Review Complete: All Reviews

### Reviewer 1
[full review output]

### Reviewer 2
[full review output]

### Reviewer 3
[full review output]

### Issue Comparison
| Issue | R1 | R2 | R3 |
|-------|----|----|----|
| [issue 1] | ✓ | ✓ | - |
| [issue 2] | - | ✓ | ✓ |
| [issue 3] | ✓ | - | - |

### My Recommendation
[Which issues I think should be addressed and why]
```

**If --conflict debate:**

For conflicting review findings:
1. Identify disagreements (one reviewer says issue, another says fine)
2. Spawn debate round for disputed items
3. Resolve or escalate to user

```
## Review Debate

### Disputed Point: [issue]
**Reviewer 1 says:** [this is a bug because...]
**Reviewer 2 says:** [this is fine because...]

**Resolution:** [outcome]

### Unresolved Disputes
[issues that need human decision]
```

### Step 6: No-Issues Path

If reviewers find no significant issues:

```
## Parallel Review Complete: ✓ Clean

[N] independent reviewers found no critical issues or warnings.

### Minor Suggestions (Optional)
- [any style/preference suggestions]

### Verdict
Code looks good! Ready to use as-is.
```

## Error Handling

### Missing Input
If no task or code/file provided:
- Ask: "Please provide either a coding task or file path(s) to review."

### File Not Found
If file path provided but doesn't exist:
- "File not found: [path]. Please check the path and try again."
- Do not proceed until valid file(s) provided

### Reviewer Timeout
If any reviewer takes too long to respond:
- Continue with remaining reviewers
- Note: "[N] of [M] reviewers responded. Findings may be incomplete."

### Partial Reviewer Failure
If some reviewers fail but others succeed:
- Present findings from successful reviewers
- Note which reviewers failed
- Highlight if any high-confidence issues were found by remaining reviewers

### Single Reviewer Result
When only 1 reviewer responds (due to failure or `--count 1`):
- Present findings without "consensus" language
- Note: "Single reviewer analysis. Consider running with more reviewers for higher confidence."

## Token Efficiency Rules
<!-- SYNC: token-efficiency-review -->

1. **Parallel reviewers**: Always launch all Task agents in a single message
2. **Deduplicate early**: Don't repeat the same issue from multiple reviewers
3. **Severity triage**: Focus output on CRITICAL and WARNING first
4. **Skip empty sections**: Don't output "No critical issues" headers, just omit

## Deliberation, Not Implementation
<!-- SYNC: deliberation-disclaimer -->

This command is a **deliberation phase**—it presents proposed fixes but does not auto-apply. The workflow:

1. Code is generated (or provided)
2. Parallel reviewers analyze independently
3. Aggregated review with proposed fixes presented
4. User approves before any changes are made

## Example Usage

**Generate and review:**
```
/generation_and_review implement a JWT authentication middleware
```

**Review existing file:**
```
/generation_and_review src/utils/validators.ts
```

**Review with more reviewers:**
```
/generation_and_review -n 5 the entire auth module
```

**Show all reviews without aggregation:**
```
/generation_and_review --conflict show_all src/api/payments.ts
```
