---
description: Quick code review by Codex - get a second opinion without debate
---

# Council Simple Review

Quick code review by sending code to Codex for external perspective. No debate—just get a second opinion.

## Arguments

After the skill invocation, user provides either:
- File path(s) to review
- Code snippet directly
- Description of what to focus on (e.g., "review the auth middleware")

## Workflow

### Step 1: Gather Code to Review

Based on user input:
- **File paths**: Read the specified files
- **Code snippet**: Use the provided code directly
- **Description**: Use Glob/Grep to find relevant files, confirm with user

If reviewing multiple files, list them and confirm scope before proceeding.

### Step 2: Send to Codex for Review

Use the Codex review command directly for cleaner output:

```bash
codex exec "Review this code. Focus on:
- Bugs and logic errors
- Security vulnerabilities
- Performance issues
- Edge cases not handled
- Code clarity improvements

Be specific with line references. Here's the code:

FILE: [filename]
```
[code content]
```

Provide a structured review with severity levels (critical/warning/suggestion)." "WORKING_DIR"
```

Or for file-based review, use Codex's built-in review:
```bash
codex review [file_path]
```

### Step 3: Present Codex's Review

Format the output cleanly:

```
## Codex Review: [file/scope]

### Critical Issues
- [issue]: [description] (line X)

### Warnings
- [issue]: [description] (line X)

### Suggestions
- [suggestion]: [description] (line X)

### Summary
[Codex's overall assessment]
```

If Codex found no issues, report that clearly:
```
## Codex Review: [file/scope]

✓ No issues found. Code looks good to Codex.
```

### Step 4: Optional - Claude's Quick Take

After presenting Codex's review, briefly note if you (Claude) agree or see anything Codex missed. Keep this short (2-3 sentences max) to stay token-efficient.

```
**Claude's note:** [brief agreement or additional observation]
```

## Token Efficiency

- Don't re-analyze what Codex already covered thoroughly
- Skip Claude's take if Codex review is comprehensive and you fully agree
- For large files, ask user to specify which functions/sections to focus on

## Example Usage

User: `/council_simple_review src/auth/middleware.ts`

1. Read the file
2. Send to Codex for review
3. Present structured feedback
4. Add brief Claude note if needed

User: `/council_simple_review the payment processing logic`

1. Search for payment-related files
2. Confirm scope with user
3. Send to Codex
4. Present results
