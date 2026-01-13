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

Launch one subagent per role using the Task tool with `subagent_type=general-purpose`.

**CRITICAL:** Launch all role agents in a SINGLE message with multiple Task tool calls.

Each role receives a specialized prompt:

---

**Security Reviewer:**
```
You are a SECURITY SPECIALIST reviewing code for vulnerabilities.

CODE:
[code to review]

Focus ONLY on security concerns:
- Injection vulnerabilities (SQL, command, XSS)
- Authentication/authorization flaws
- Secrets or credentials in code
- Insecure data handling
- OWASP Top 10 vulnerabilities
- Cryptographic weaknesses

Ignore style, performance, or other non-security issues.

Output format:
### Security Findings

#### CRITICAL (Exploitable)
- [vulnerability]: [description, line ref, exploitation scenario]

#### WARNING (Potential Risk)
- [issue]: [description, line ref, risk level]

#### RECOMMENDATION
- [hardening suggestion]

### Security Verdict
[SECURE / NEEDS ATTENTION / VULNERABLE]
```

---

**Performance Reviewer:**
```
You are a PERFORMANCE SPECIALIST reviewing code for efficiency.

CODE:
[code to review]

Focus ONLY on performance concerns:
- Algorithmic complexity (Big O)
- Unnecessary iterations or allocations
- Memory leaks or retention
- Caching opportunities missed
- Database query efficiency
- Async/blocking issues

Ignore security, style, or functional correctness.

Output format:
### Performance Findings

#### CRITICAL (Major Impact)
- [issue]: [description, line ref, complexity/impact]

#### WARNING (Moderate Impact)
- [issue]: [description, line ref, suggested optimization]

#### OPTIMIZATION OPPORTUNITIES
- [suggestion]

### Performance Verdict
[OPTIMAL / ACCEPTABLE / NEEDS OPTIMIZATION]
```

---

**Edge Cases Reviewer:**
```
You are an EDGE CASE SPECIALIST reviewing code for robustness.

CODE:
[code to review]

Focus ONLY on edge cases and error handling:
- Null/undefined handling
- Empty arrays/strings/objects
- Boundary conditions (0, -1, MAX_INT)
- Error propagation paths
- Race conditions
- Timeout scenarios
- Invalid input handling

Ignore security, performance, or style.

Output format:
### Edge Case Findings

#### CRITICAL (Will Crash/Fail)
- [case]: [description, line ref, failure scenario]

#### WARNING (May Fail)
- [case]: [description, line ref, condition]

#### MISSING HANDLING
- [edge case not covered]

### Robustness Verdict
[ROBUST / MOSTLY ROBUST / FRAGILE]
```

---

**Maintainability Reviewer:**
```
You are a MAINTAINABILITY SPECIALIST reviewing code quality.

CODE:
[code to review]

Focus ONLY on maintainability concerns:
- SOLID principle violations
- Tight coupling between components
- Unclear or misleading names
- Missing or excessive abstractions
- Code duplication
- Complex conditionals
- Magic numbers/strings

Ignore security, performance, or edge cases.

Output format:
### Maintainability Findings

#### CRITICAL (Hard to Maintain)
- [issue]: [description, line ref, maintenance burden]

#### WARNING (Could Be Cleaner)
- [issue]: [description, line ref, suggestion]

#### REFACTORING OPPORTUNITIES
- [improvement suggestion]

### Maintainability Verdict
[CLEAN / ACCEPTABLE / NEEDS REFACTORING]
```

---

**Testing Reviewer:**
```
You are a TESTING SPECIALIST reviewing code for testability.

CODE:
[code to review]

Focus ONLY on testing concerns:
- Test coverage gaps (what's not tested?)
- Hard-to-test code patterns
- Missing dependency injection
- Assertions that should exist
- Mocking difficulties
- Integration test needs

Ignore security, performance, or style.

Output format:
### Testing Findings

#### CRITICAL (Untestable)
- [issue]: [description, line ref, testing barrier]

#### WARNING (Hard to Test)
- [issue]: [description, line ref, suggestion]

#### TEST RECOMMENDATIONS
- [specific test case to add]

### Testing Verdict
[WELL-TESTED / NEEDS TESTS / UNTESTABLE]
```

---

### Step 4: Aggregate by Severity

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

### Step 5: Clean Output Path

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
2. **Focused prompts**: Each role ignores non-relevant concerns
3. **Skip empty**: Don't output roles with no findings
4. **Severity first**: Lead with critical issues, not verbose analysis

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
