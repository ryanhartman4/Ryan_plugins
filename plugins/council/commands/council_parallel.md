---
description: Run Claude and Codex in parallel, use confidence voting with synthesis fallback
---

# Council Parallel Generation

Run Claude and Codex in parallel on the same task, then apply confidence voting with synthesis fallback.

## Arguments

The user's coding task/prompt follows the skill invocation.

## Workflow

### Step 1: Parse the Task

Extract the coding task from the user's prompt. If no task provided, ask what they want the council to work on.

### Step 2: Complexity Check

For trivial tasks (single function, <20 lines, no algorithmic complexity), skip the council and just solve directly. Inform user: "Task is straightforward, skipping council."

### Step 3: Run Codex

Execute Codex on the task using the helper script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/run_codex.sh "TASK_PROMPT" "WORKING_DIR"
```

Where:
- `TASK_PROMPT` is the user's coding request
- `WORKING_DIR` is the current working directory

### Step 4: Generate Claude's Solution

While waiting for Codex, generate your own solution to the same task. Think through the problem independently without being influenced by Codex's approach.

### Step 5: Compare Solutions (Confidence Voting)

Analyze both solutions for agreement. Check:

1. **Structural agreement**: Same overall approach/architecture?
2. **Logic agreement**: Same algorithm/business logic?
3. **Edge case handling**: Similar error handling and edge cases?

Agreement levels:
- **STRONG_AGREE**: Solutions are functionally equivalent (use either)
- **PARTIAL_AGREE**: Same approach, minor differences (review for improvements)
- **DISAGREE**: Fundamentally different approaches (full synthesis)

### Step 6: Output Based on Agreement (Balanced Strategy)

**If STRONG_AGREE:**
```
## Council Result: ✓ Strong Consensus

Both models produced functionally equivalent solutions. Confidence: HIGH

[Present the solution]

### Agreement Summary
- Both models chose: [approach]
- Key consensus points: [what they agreed on]
```

**If PARTIAL_AGREE:**
```
## Council Result: ✓ Consensus with Refinements

Models agreed on approach but had minor differences. Reviewing for best elements...

### Base Solution
[The shared approach]

### Refinements Extracted
- From Claude: [any improvements worth keeping]
- From Codex: [any improvements worth keeping]

### Final Refined Solution
[Solution with best refinements merged]
```

**If DISAGREE:**
```
## Council Result: ⚖️ Full Synthesis Required

Models took fundamentally different approaches. Analyzing strengths...

### Claude's Approach
- Strategy: [description]
- Strengths: [what it does well]
- Weaknesses: [limitations]

### Codex's Approach
- Strategy: [description]
- Strengths: [what it does well]
- Weaknesses: [limitations]

### Synthesized Solution
[Merge the strongest elements from both]

### Synthesis Rationale
[Why specific elements were chosen from each]
```

## Token Efficiency Rules

1. **Context compression**: When sending to Codex, include only:
   - The specific task
   - Relevant file contents (not entire codebase)
   - Key constraints

2. **Early termination**: If both solutions are identical, don't analyze further.

## Deliberation, Not Implementation

This command is a **deliberation phase**—it does not auto-apply changes. The workflow:

1. Council discusses and reaches consensus
2. User reviews the proposed solution
3. User says "do it" or enters Plan mode to implement

This separation ensures you see the reasoning and can modify the approach before any code is written.

## Example Usage

User: `/council_parallel implement a debounce function in TypeScript`

1. Send to Codex: "Implement a debounce function in TypeScript"
2. Generate Claude solution independently
3. Compare approaches
4. Output consensus or synthesized result
5. **User approves** → then implement
