---
description: Specialized role-based code review with security, performance, and other experts
---

# Role-Based Review

Spawn specialized reviewer Claudes, each focused on a specific aspect of code quality. Get expert-level feedback from security, performance, edge case, maintainability, and testing perspectives—all in parallel.

## Arguments

The user provides code to review:
- File path(s)
- Code snippet directly
- Description of what to review (e.g., "review the auth module")

**Optional flags:**
- `--roles <list>`: Comma-separated roles to use (default: all 5 roles)
- `--context <mode>`: Context strategy - `full` (default), `compressed`

## Input Validation

Before executing, validate all flags:

### Validation Rules

| Flag | Valid Values | Default | On Invalid |
|------|-------------|---------|------------|
| `--roles` | security, performance, edge_cases, maintainability, testing | all 5 | Skip invalid, warn |
| `--context` | full, compressed | full | Warn and use default |

### Role Validation

Parse comma-separated roles and validate each:
- Valid role: Include in review
- Invalid role: Skip with warning "Invalid role: [value]. Valid roles: security, performance, edge_cases, maintainability, testing. Skipping."
- Duplicate roles: Deduplicate silently
- All roles invalid: "No valid roles specified. Using all 5 default roles."
- Empty `--roles` flag: "No roles specified. Using all 5 default roles."

### Error Messages

```
Invalid role: [value]. Valid roles: security, performance, edge_cases, maintainability, testing. Skipping.
Invalid --context: [value]. Valid options: full, compressed. Using default (full).
```

### Configuration Display

After parsing, show:
```
## Configuration
- Roles: [list of valid roles]
- Context: [mode]
```

If any validation warnings occurred, ask: "Continue with these settings?"

## Available Roles

| Role | Focus Area | Looks For |
|------|------------|-----------|
| `security` | Vulnerabilities | Injection, XSS, auth bypass, secrets exposure, OWASP Top 10 |
| `performance` | Efficiency | O(n) complexity, memory leaks, unnecessary allocations, caching opportunities |
| `edge_cases` | Robustness | Null/undefined, boundary conditions, error paths, race conditions |
| `maintainability` | Code quality | SOLID violations, tight coupling, unclear naming, missing abstractions |
| `testing` | Testability | Coverage gaps, untestable code, missing mocks, assertion quality |

## Workflow

### Step 1: Gather Code to Review

Based on user input:
- **File paths**: Read the specified files
- **Code snippet**: Use the provided code directly
- **Description**: Use Glob/Grep to find relevant files, confirm with user

If reviewing multiple files, list them and confirm scope.

### Step 2: Parse Role Selection

If `--roles` provided, use only those roles. Otherwise, use all 5.

Examples:
- `--roles security,performance` → only security and performance reviewers
- `--roles edge_cases` → single focused review
- (no flag) → all 5 roles

### Step 3: Spawn Role-Specialized Reviewers

For each selected role, load the agent definition from the `agents/` directory.

**CRITICAL:** Launch all role agents in a SINGLE message with multiple Task tool calls using `run_in_background=true`.

**Setup:**
1. Create the handoff directory: `mkdir -p .parallel`
2. If `.gitignore` exists and doesn't contain `.parallel`, append `.parallel` to it

**Agent Loading Process:**

1. For each role in the selected roles list, read the agent definition file:
   - `security` → Read `${CLAUDE_PLUGIN_ROOT}/agents/security_agent.md`
   - `performance` → Read `${CLAUDE_PLUGIN_ROOT}/agents/performance_agent.md`
   - `edge_cases` → Read `${CLAUDE_PLUGIN_ROOT}/agents/edge_cases_agent.md`
   - `maintainability` → Read `${CLAUDE_PLUGIN_ROOT}/agents/maintainability_agent.md`
   - `testing` → Read `${CLAUDE_PLUGIN_ROOT}/agents/testing_agent.md`

2. Construct the prompt for each agent using the template below

3. Launch the Task tool with `subagent_type=general-purpose` and `run_in_background=true` for each role agent

**Agent Prompt Template:**

```
[Full content of the agent definition file]

---

CODE TO REVIEW:
[the code being reviewed]

FILES:
[file paths if applicable]

---

PROGRESS REPORTING:
Report progress with these checkpoint markers:
- [CHECKPOINT: READING_CODE]
- [CHECKPOINT: ANALYZING]
- [CHECKPOINT: WRITING_FINDINGS]
- [TASK_COMPLETE] Summary: [1 sentence] Handoff: .parallel/role_[role]_review.md

HANDOFF OUTPUT (CRITICAL - keeps orchestrator context clean):
Write your detailed findings to `.parallel/role_[role]_review.md` in this format:

```markdown
# [Role] Review Output

## Summary
[1-2 sentence summary of findings]

## Verdict
[SECURE/OPTIMAL/ROBUST/CLEAN/WELL-TESTED] or [NEEDS ATTENTION/NEEDS OPTIMIZATION/FRAGILE/NEEDS REFACTORING/NEEDS TESTS]

## Critical Issues
[List with severity markers, or "None found"]

## Warnings
[List with severity markers, or "None found"]

## Recommendations
[Optional improvements]
```

Your final message to the orchestrator should be MINIMAL:
```
[TASK_COMPLETE]
Summary: [1 sentence verdict]
Handoff: .parallel/role_[role]_review.md
```
```

**Example - Launching a Security Reviewer:**

```
Task tool call:
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    [Contents of agents/security_agent.md]

    ---

    CODE TO REVIEW:
    [code snippet or file contents]

    FILES:
    src/api/auth.ts

    ---

    PROGRESS REPORTING:
    - [CHECKPOINT: READING_CODE]
    - [CHECKPOINT: ANALYZING]
    - [CHECKPOINT: WRITING_FINDINGS]
    - [TASK_COMPLETE] Summary: [1 sentence] Handoff: .parallel/role_security_review.md

    Write detailed findings to `.parallel/role_security_review.md`.
    Final message should be minimal: [TASK_COMPLETE] Summary: ... Handoff: ...
```

---

### Step 3.5: Progress Monitoring

Monitor agent progress using tail-based output checking (minimal context approach).

**Monitoring Loop (every 10-15 seconds):**

1. For each running agent:
   - Use `tail -n 10 <output_file>` via Bash to check recent output
   - **Do NOT use TaskOutput during monitoring** - it pulls full output into context
   - Parse for checkpoint markers: `[CHECKPOINT: ...]` or `[TASK_COMPLETE]`

2. Update progress visualization:
   ```
   ## Review Progress [HH:MM:SS]

   Security     [████████████████████] 100% - Complete
   Performance  [████████████░░░░░░░░]  66% - Writing findings
   Edge Cases   [████░░░░░░░░░░░░░░░░]  33% - Analyzing
   Maintain.    [░░░░░░░░░░░░░░░░░░░░]   0% - Reading code
   Testing      [████████████████░░░░]  80% - Writing findings
   ```

3. Checkpoint-based progress phases:

   | Phase | Progress | Checkpoint Marker |
   |-------|----------|-------------------|
   | Reading code | 0% → 33% | `[CHECKPOINT: READING_CODE]` |
   | Analyzing | 33% → 66% | `[CHECKPOINT: ANALYZING]` |
   | Writing findings | 66% → 100% | `[CHECKPOINT: WRITING_FINDINGS]` |

4. When all agents show `[TASK_COMPLETE]`:
   - Use `TaskOutput` with `block=true` to get final minimal message
   - Extract summary and handoff path from each completed agent
   - **Do NOT read handoff file contents into orchestrator context**

**Context Efficiency:**
```
Orchestrator context (minimal):
├── Security: complete | "No critical issues found" | .parallel/role_security_review.md
├── Performance: complete | "2 optimization opportunities" | .parallel/role_performance_review.md
└── Edge Cases: running | ...

Handoff files (full details, read only for final aggregation):
├── .parallel/role_security_review.md
├── .parallel/role_performance_review.md
└── ...
```

---

### Step 4: Aggregate by Severity

**Read handoff files** from `.parallel/` to compile findings. This is the only time the orchestrator reads the full output.

Collect all role outputs and organize by severity across all roles:

```
## Role-Based Review Complete

### Code Reviewed
[file paths or code summary]

---

## Critical Issues (Must Fix)

### Security
- [critical security findings]

### Performance
- [critical performance findings]

### Edge Cases
- [critical edge case findings]

---

## Warnings (Should Fix)

### Security
- [security warnings]

### Maintainability
- [maintainability warnings]

### Testing
- [testing warnings]

---

## Recommendations (Nice to Have)

[Aggregated suggestions from all roles]

---

## Verdict Summary

| Role | Verdict |
|------|---------|
| Security | [SECURE/NEEDS ATTENTION/VULNERABLE] |
| Performance | [OPTIMAL/ACCEPTABLE/NEEDS OPTIMIZATION] |
| Edge Cases | [ROBUST/MOSTLY ROBUST/FRAGILE] |
| Maintainability | [CLEAN/ACCEPTABLE/NEEDS REFACTORING] |
| Testing | [WELL-TESTED/NEEDS TESTS/UNTESTABLE] |

### Overall Assessment
[1-2 sentence summary of most important findings]

---
**Next step:** Say "do it" to apply fixes, or ask about specific findings
```

### Step 5: Cleanup

After presenting results to the user:

```bash
rm -rf .parallel
```

This removes all temporary handoff files. If the user wants to review detailed role outputs later, they can request to skip cleanup.

### Step 6: Clean Output Path

If a role finds no issues:
- Don't include empty sections for that role
- Note in verdict: "Security: SECURE (no issues found)"

If all roles find no issues:
```
## Role-Based Review Complete: ✓ All Clear

All [N] specialized reviewers found no significant issues.

### Verdicts
| Role | Verdict |
|------|---------|
| Security | SECURE |
| Performance | OPTIMAL |
| Edge Cases | ROBUST |
| Maintainability | CLEAN |
| Testing | WELL-TESTED |

Minor suggestions (if any):
- [optional improvements]
```

## Error Handling

### Missing Code to Review
If no code, file path, or description provided:
- Ask: "Please provide code to review (file path, code snippet, or description like 'the auth module')."

### File Not Found
If file path provided but doesn't exist:
- "File not found: [path]. Please check the path and try again."
- Do not proceed until valid file(s) provided

### Description Resolution Failure
If description provided but no matching files found:
- "Could not find files matching '[description]'. Please provide specific file paths."

### Role Agent Timeout
If a role agent takes too long to respond:
- Continue with other roles
- Note in output: "[Role] review timed out and is not included."

### Partial Role Failure
If some role agents fail but others succeed:
- Present findings from successful roles
- Note which roles failed: "[Role] review failed and is not included."
- Adjust verdict table to show only completed roles

### Single Role Result
When only 1 role completes (due to `--roles` or failures):
- Present single role's findings
- Skip verdict comparison table

## Token Efficiency Rules
<!-- SYNC: token-efficiency-role -->

1. **Parallel execution**: Launch all role agents in a single message
2. **Background execution**: Launch all role agents with `run_in_background=true`
3. **File-based handoff**: Reviewers write to `.parallel/` files; orchestrator only receives 1-line summaries
4. **Tail-based monitoring**: Use `tail -n 10` on output files, NOT TaskOutput (avoids pulling full output into context)
5. **Focused prompts**: Each role ignores non-relevant concerns
6. **Skip empty**: Don't output roles with no findings
7. **Severity first**: Lead with critical issues, not verbose analysis
8. **Cleanup after completion**: Remove `.parallel/` directory after presenting results

## Deliberation, Not Implementation
<!-- SYNC: deliberation-disclaimer -->

This command presents findings but does not auto-apply fixes. User reviews and approves changes.

## Example Usage

**Full role-based review:**
```
/role_based_review src/api/auth.ts
```

**Security and performance only:**
```
/role_based_review --roles security,performance src/payments/
```

**Single focused review:**
```
/role_based_review --roles edge_cases the new validation logic
```

**Review with fresh context:**
```
/role_based_review --context compressed src/core/engine.ts
```
