---
description: Run multiple Claudes in parallel, use confidence voting with synthesis fallback
---

# Parallel Generation

Run multiple Claude instances in parallel on the same task, then apply confidence voting with synthesis fallback.

## Arguments

The user's coding task/prompt follows the skill invocation.

**Optional flags:**
- `--count N` or `-n N`: Number of parallel instances (default: 3)
- `--model <model>`: Model for all instances (sonnet, opus, haiku)
- `--conflict <mode>`: Resolution mode - `majority_vote` (default), `show_all`, `debate`
- `--context <mode>`: Context strategy - `compressed` (default), `full`

## Input Validation

Before executing, validate all flags and show configuration:

### Validation Rules

| Flag | Valid Values | Default | On Invalid |
|------|-------------|---------|------------|
| `--count` | 2-7 (integer) | 3 | Warn and use default |
| `--model` | sonnet, opus, haiku | sonnet | Warn and use default |
| `--conflict` | majority_vote, show_all, debate | majority_vote | Warn and use default |
| `--context` | compressed, full | compressed | Warn and use default |

### Error Messages

```
Invalid --count: [value]. Must be 2-7. Using default (3).
Invalid --model: [value]. Valid options: sonnet, opus, haiku. Using default (sonnet).
Invalid --conflict: [value]. Valid options: majority_vote, show_all, debate. Using default (majority_vote).
Invalid --context: [value]. Valid options: full, compressed. Using default (full).
```

### Configuration Display

After parsing, show:
```
## Configuration
- Instances: [N]
- Model: [model]
- Conflict resolution: [mode]
- Context: [mode]
```

If any validation warnings occurred, ask: "Continue with these settings?"

## Workflow

### Step 1: Parse Task and Flags

Extract the coding task and any flags from the user's input.

Example inputs:
- `/parallel_generation implement a debounce function` → 3 instances, majority_vote
- `/parallel_generation -n 2 --conflict show_all add caching to the API` → 2 instances, show all

If no task provided, ask what they want the parallel Claudes to work on.

### Step 2: Complexity Check

For trivial tasks (single function, <20 lines, no algorithmic complexity), skip the parallel execution and just solve directly. Inform user: "Task is straightforward, skipping parallel generation."

### Step 3: Spawn Parallel Claude Instances

Launch N Claude subagents using the Task tool with `subagent_type=general-purpose`.

**CRITICAL:** Launch all agents in a SINGLE message with multiple Task tool calls to ensure true parallel execution.

For each agent, provide a focused prompt based on context mode:

**If --context full (default):**
```
You are Claude Instance [N] in a parallel generation task.

TASK: [user's coding task]

Generate a complete solution. Think through the problem independently. Do not hedge or provide multiple alternatives - commit to your best approach.

Output format:
1. Brief approach summary (2-3 sentences)
2. Complete code solution
3. Key design decisions made
```

**If --context compressed:**
```
TASK: [user's coding task]

RELEVANT FILES:
[only files directly needed for the task]

Generate a complete solution with:
1. Approach summary
2. Code
3. Key decisions
```

### Step 4: Collect and Compare Solutions

Wait for all agents to complete. Analyze solutions for agreement:

**Check for:**
1. **Structural agreement**: Same overall approach/architecture?
2. **Logic agreement**: Same algorithm/business logic?
3. **Edge case handling**: Similar error handling and edge cases?

**Agreement levels:**
- **STRONG_AGREE**: Majority (≥2/3) produced functionally equivalent solutions
- **PARTIAL_AGREE**: Same approach, minor implementation differences
- **DISAGREE**: Fundamentally different approaches, no clear majority

### Step 5: Apply Conflict Resolution

**If --conflict majority_vote (default):**

When STRONG_AGREE:
```
## Parallel Generation Result: ✓ Strong Consensus

[N] Claude instances independently produced equivalent solutions. Confidence: HIGH

### Agreed Solution
[Present the consensus solution]

### Agreement Summary
- Approach chosen by majority: [description]
- Key consensus points: [what they agreed on]
- Dissenting view (if any): [brief note on minority opinion]
```

When PARTIAL_AGREE:
```
## Parallel Generation Result: ✓ Consensus with Refinements

Instances agreed on approach but had minor differences. Synthesizing best elements...

### Base Approach
[The shared approach]

### Refinements Extracted
- Instance 1 contributed: [improvement]
- Instance 2 contributed: [improvement]
- Instance 3 contributed: [improvement]

### Synthesized Solution
[Solution with best refinements merged]
```

When DISAGREE:
```
## Parallel Generation Result: ⚖️ Synthesis Required

Instances took fundamentally different approaches. Analyzing strengths...

### Approach Comparison
| Instance | Strategy | Strengths | Weaknesses |
|----------|----------|-----------|------------|
| 1 | [desc] | [pros] | [cons] |
| 2 | [desc] | [pros] | [cons] |
| 3 | [desc] | [pros] | [cons] |

### Synthesized Solution
[Merge the strongest elements]

### Synthesis Rationale
[Why specific elements were chosen]
```

**If --conflict show_all:**
```
## Parallel Generation Result: All Solutions

### Instance 1
**Approach:** [summary]
**Key difference:** [what distinguishes this approach]
**Core snippet:**
[only the key 10-20 lines that show the approach - not full code]

### Instance 2
**Approach:** [summary]
**Key difference:** [what distinguishes this approach]
**Core snippet:**
[only the key 10-20 lines that show the approach - not full code]

### Instance 3
**Approach:** [summary]
**Key difference:** [what distinguishes this approach]
**Core snippet:**
[only the key 10-20 lines that show the approach - not full code]

### Comparison Matrix
| Aspect | Instance 1 | Instance 2 | Instance 3 |
|--------|------------|------------|------------|
| Approach | ... | ... | ... |
| Performance | ... | ... | ... |
| Readability | ... | ... | ... |

**Note:** Full solutions available on request. Showing snippets to conserve context.

### Recommendation
[Which solution I'd recommend and why, but user decides]
```

**If --conflict debate:**
Identify disagreement points and spawn a debate round:
1. Present the conflicting approaches
2. Have instances argue their positions (max 2 rounds)
3. Resolve to consensus or present unresolved points to user

```
## Parallel Generation Result: Debate

### Debate Point 1: [issue]
**Instance 1 argues:** [position]
**Instance 2 argues:** [counter position]
**Resolution:** [outcome after debate]

### Final Consensus
[Solution after debate resolution]

### Unresolved (Human Decision Needed)
[Any points that couldn't be resolved]
```

## Error Handling

### Missing Task
If no task provided after parsing flags:
- Ask: "What task should the parallel Claudes work on?"

### Agent Timeout
If any agent takes too long to respond:
- Continue with remaining agents if at least 2 completed
- If only 1 completed: Show single result with note "Only 1 agent responded. Results may be less reliable."
- If 0 completed: "All agents timed out. Please try again or simplify the task."

### Partial Failure
If some agents fail but others succeed:
- 3 agents, 2 succeed: Proceed with comparison, note "1 agent failed, comparing 2 responses"
- 3 agents, 1 succeeds: Show single result with caveat
- Note which agents failed without full error dumps

### Count = 2 Special Case
When `--count 2`:
- "Majority vote" becomes "agreement check" (both must agree for high confidence)
- STRONG_AGREE requires both solutions to be equivalent
- DISAGREE triggers synthesis (no tie-breaker available)

## Token Efficiency Rules
<!-- SYNC: token-efficiency-parallel -->

1. **Parallel execution**: Always launch all Task agents in a single message
2. **Early termination**: If all solutions are identical, skip detailed analysis
3. **Context compression**: When --context compressed, send only essential files
4. **Batch comparison**: Compare all solutions at once, not pairwise

## Deliberation, Not Implementation
<!-- SYNC: deliberation-disclaimer -->

This command is a **deliberation phase**—it does not auto-apply changes. The workflow:

1. Parallel Claudes generate and reach consensus
2. User reviews the proposed solution
3. User says "do it" or enters Plan mode to implement

This separation ensures you see the reasoning and can modify the approach before any code is written.

## Example Usage

**Basic usage:**
```
/parallel_generation implement a rate limiter with sliding window
```

**With flags:**
```
/parallel_generation -n 2 --conflict show_all implement user authentication
```

**Compressed context for fresh perspective:**
```
/parallel_generation --context compressed refactor the payment processing module
```
