---
description: One model generates, the other reviews, debate on disagreements
---

# Council Review Chain

One model generates code, the other reviews it. Debate and iterate when disagreements arise.

## Arguments

The user's code or coding task follows the skill invocation.

## Workflow

### Step 1: Determine Review Mode

Two modes based on input:
- **Code provided**: User wants existing code reviewed by the council
- **Task provided**: Generate code first, then cross-review

### Step 2: Initial Generation (if task provided)

Generate the initial solution using Claude. This becomes the artifact under review.

### Step 3: Cross-Review with Codex

Send the code to Codex for review:

```bash
~/.claude/plugins/council/scripts/run_codex.sh "Review this code for bugs, edge cases, performance issues, and improvements. Be specific and critical:

CODE:
[insert code here]

Provide specific line-by-line feedback." "WORKING_DIR"
```

### Step 4: Analyze Review Feedback

Parse Codex's review for:
- **Critical issues**: Bugs, security flaws, logic errors
- **Improvements**: Performance, readability, best practices
- **Stylistic**: Preferences without functional impact

### Step 5: Claude Counter-Review

Review Codex's feedback:
- Agree with valid points
- Dispute incorrect criticisms with reasoning
- Identify issues Codex missed

### Step 6: Debate Resolution (if disagreements)

For each disputed point:

```
## Debate Point: [issue]

**Codex argues:** [their position]
**Claude argues:** [counter position]

**Resolution:** [final decision with rationale]
```

Maximum 2 debate rounds to prevent infinite loops.

### Step 7: Final Output

```
## Council Review Complete

### Code Under Review
[original or generated code]

### Consensus Issues (Both Agreed)
- [ ] Issue 1: [description] - [fix]
- [ ] Issue 2: [description] - [fix]

### Resolved Debates
- Debate 1: [summary] → Resolved: [outcome]

### Final Improved Code
[code with all agreed fixes applied]

### Unresolved (Human Decision Needed)
[any points where models couldn't agree after 2 rounds]
```

## Token Efficiency Rules

1. **Incremental context**: Don't re-send full code each round. Send only:
   - Disputed code sections
   - Specific debate points

2. **Batch feedback**: Group related issues to minimize round-trips

3. **Early exit**: If Codex review finds no issues, skip debate phase

4. **Scope limit**: For large files, focus review on changed/critical sections

## Example Usage

User: `/council_review
function processOrder(order) {
  const total = order.items.reduce((sum, item) => sum + item.price, 0);
  return { ...order, total, status: 'processed' };
}`

1. Claude analyzes code
2. Codex reviews for issues
3. Debate any disagreements
4. Output consolidated review with fixes
