---
description: Execute multiple tasks in parallel with automatic dependency management
---

# Swarm

Break down large tasks into MECE (Mutually Exclusive, Collectively Exhaustive) sub-tasks and execute them in parallel waves, applying changes directly to the codebase. Unlike other parallel_claudes commands that deliberate before acting, swarm executes immediately after plan approval.

## Arguments

The user provides a task description:
- Complex feature request (e.g., "add user authentication with routes, models, and tests")
- Multi-file refactoring (e.g., "rename UserService to AccountService across the codebase")
- Any task that can be decomposed into independent sub-tasks

**Optional flags:**
- `--count N` / `-n N`: Max concurrent agents per wave (default: 5)
- `--model <model>`: Model for all agents — `sonnet`, `opus`, `haiku` (default: sonnet)
- `--context <mode>`: Context strategy — `compressed` (default), `full`
- `--agent <type>`: Default agent type for tasks — `general-purpose` (default), or any available subagent type

**Note:** Swarm does not support `--conflict` mode (unlike other parallel_claudes commands) because it executes tasks directly rather than deliberating on solutions.

**Per-task agent types:** Individual tasks can use specialized agents (e.g., `feature-dev:code-reviewer` for review tasks). See "Specialized Agent Types" section below.

## Input Validation

Before executing, validate all flags:

### Validation Rules

| Flag | Valid Values | Default | On Invalid |
|------|-------------|---------|------------|
| `--count` / `-n` | 2-7 (integer) | 5 | Clamp to range, warn |
| `--model` | sonnet, opus, haiku | sonnet | Warn and use default |
| `--context` | compressed, full | compressed | Warn and use default |

### Error Messages

```
Invalid --count: [value]. Must be 2-7. Using default (5).
Invalid --model: [value]. Valid options: sonnet, opus, haiku. Using default (sonnet).
Invalid --context: [value]. Valid options: full, compressed. Using default (full).
```

### Configuration Display

After parsing, show:
```
## Configuration
- Max concurrent agents: [count]
- Model: [model]
- Context: [mode]
```

If any validation warnings occurred, ask: "Continue with these settings?"

## Workflow

### Step 1: Parse Task

Extract the task description and any flags from user input.

If no task provided:
- Ask: "Please describe the task you want to execute (e.g., 'add user authentication with models, routes, and tests')."

### Step 2: MECE Decomposition

Analyze the task and break it into sub-tasks following MECE principles:

**MECE Guidelines:**
- **Mutually Exclusive**: No two tasks should modify the same logical unit. If file overlap is unavoidable, mark as dependent.
- **Collectively Exhaustive**: All parts of the request must be covered. No gaps.
- **Atomic**: Each task should be completable by one agent in a reasonable scope.
- **Dependency-aware**: Identify what must exist before other tasks can start.

**Decomposition Process:**
1. Identify the major components needed (models, services, routes, tests, etc.)
2. For each component, determine if it can run independently
3. Map dependencies: "Task B needs Task A's output"
4. Estimate which files each task will create or modify
5. Group independent tasks into waves

**Task Types - Implementation vs Research:**
When decomposing, identify each task's type:
- **Implementation tasks**: Output is files created/modified. Downstream tasks can read those files directly.
- **Research tasks**: Output is findings/analysis text. Downstream tasks need the actual text output passed to them.

For research tasks that feed into later waves, consider:
- Is the research actually needed, or can the implementation task do its own quick exploration?
- If research IS needed, ensure you'll extract and pass the full findings (see Step 5)
- For small codebases (<20 files), parallel research may add overhead without value—one agent can explore quickly

**When NOT to decompose:**
- Simple single-file changes → Just execute directly
- Tasks under 20 lines of changes → Execute without swarm overhead
- If only 1 task results from decomposition → Execute directly, no swarm needed
- Research-then-implement on small codebases → Single agent is often faster

### Step 3: Display Task Graph

Present the decomposition to the user for approval:

```
## Task Breakdown

### Wave 1 (no dependencies)
- [1] [Task description]
  Type: implementation | Files: [estimated files to create/modify]
  Agent: general-purpose
- [2] [Task description]
  Type: research | Output: findings passed to dependent tasks
  Agent: general-purpose

### Wave 2 (depends on Wave 1)
- [3] [Task description] (depends on: 1, 2)
  Type: implementation | Files: [estimated files]
  Agent: general-purpose
- [4] Security review of auth changes (depends on: 1, 2)
  Type: research | Output: review findings
  Agent: feature-dev:code-reviewer ← specialized

### Wave 3
- [5] [Task description] (depends on: 3, 4)
  Type: implementation | Files: [estimated files]
  Agent: general-purpose

---
Total: [N] tasks across [M] waves
Estimated agents needed: [count] (max [configured max] concurrent)
Research tasks: [count] (outputs will be extracted and passed to dependents)
```

**IMPORTANT:** Use `AskUserQuestion` to request plan approval:
```
AskUserQuestion with:
  question: "Proceed with this task breakdown?"
  header: "Swarm Plan"
  options:
    - label: "Yes, execute"
      description: "Begin parallel execution of all waves"
    - label: "Modify"
      description: "Request changes to task breakdown or agent types"
    - label: "Abort"
      description: "Cancel swarm execution"
```

**User options:**
- **Yes, execute**: Begin execution
- **Modify**: User can request changes to the decomposition (including agent types)
- **Abort**: Cancel swarm

### Step 4: Permission Warmup

Background agents cannot prompt for permissions interactively. Before launching agents, grant Edit permissions by making a minimal no-op edit to representative files.

**Process:**
1. Identify unique directories from the task breakdown's file list
2. For each directory, select one existing file that will be modified
3. Display explanation to user:
   ```
   ## Permission Warmup

   Background agents can't request edit permissions interactively.
   I'll make a small no-op edit to these files to grant permission:
   - [file1]
   - [file2]

   **Important:** When prompted, select "Always allow" or "Allow all edits" to grant
   permission for the entire session. This allows background agents to write files.
   ```
4. For each file, make a trivial edit (add a trailing newline, then remove it) using the Edit tool
5. The user selecting "Always allow" grants Edit permission to background agents for the session

**Note:** If all tasks only create new files (no modifications), this step can be skipped since Write permissions for new files don't require warmup.

### Step 5: Execute Waves

**CRITICAL:** Use `run_in_background=true` for all agents to enable progress monitoring.

For each wave:

1. **Pre-wave conflict check**: Verify no file overlaps within the wave
   - If overlap detected: Move conflicting task to next wave or serialize

2. **Launch agents**: In a SINGLE message, launch all wave tasks using Task tool with `subagent_type` set to each task's configured agent type (default: `general-purpose`)

3. **Progress monitoring loop** (every 10-15 seconds):
   - Use `TaskOutput` with `block=false` to check each agent
   - Parse output for checkpoint markers
   - Update TodoWrite with current status
   - Print progress snapshot (see Progress Visualization below)

4. **Wave completion**: Wait for all wave agents to complete before starting next wave

5. **Extract outputs for dependent tasks**: Before launching the next wave, extract actual outputs from completed agents:
   - Use `TaskOutput` with `block=true` to get final output from each completed agent
   - For **implementation tasks**: Note which files were created/modified (the files ARE the output)
   - For **research/exploration tasks**: Extract the agent's findings text—this IS the valuable output that must be passed forward
   - Store these outputs to include in dependent task prompts

**CRITICAL - Research Task Output Handling:**
When Wave N contains research/exploration tasks (mapping, analysis, investigation), their text output contains the findings. You MUST:
1. Read the full output from each research agent (not just check completion status)
2. Extract key findings, not just write your own 1-sentence summary
3. Include substantive excerpts or the full findings in Wave N+1 prompts

**Anti-pattern to avoid:**
```
❌ BAD: "Task 1 mapped the auth module" (your summary, not the agent's findings)
✅ GOOD: Include actual output: "Task 1 findings: [paste agent's analysis here]"
```

If you summarize instead of passing actual output, Wave N was wasted—Wave N+1 will just redo the work.

**Agent Prompt Template:**
```
You are executing Task [N] of a swarm operation.

TASK: [description]

DEPENDENCIES AND THEIR OUTPUTS:

[For each dependency task, include ONE of the following based on task type:]

[If dependency was an IMPLEMENTATION task:]
- Task [X] created/modified these files: [file list]
  You can read these files directly.

[If dependency was a RESEARCH/EXPLORATION task:]
- Task [X] findings:
  """
  [Paste the actual output/findings from that agent here - not your summary]
  """

CONSTRAINTS:
- Focus ONLY on this specific task
- Your file scope: [list of files you may create/modify]
- Do not modify files outside your scope
- Apply changes directly - this is an execution task, not review
- Use the dependency outputs above—don't redo research that was already done

PROGRESS REPORTING (required):
Output these markers as you work:
- [CHECKPOINT: READ_FILES] - before reading any files
- [CHECKPOINT: PLAN_CHANGES] - after reading, before making changes
- [CHECKPOINT: APPLY_CHANGES] - when applying changes
- [TASK_COMPLETE] - when finished

Execute the task now.
```

### Step 6: Handle File Conflicts

If during execution an agent needs a file another agent is modifying:

1. Detect conflict (agent reports needing file that's in-progress)
2. **Queue the blocked agent**: Pause and note "Waiting for Task N to release [file]"
3. When blocking task completes, resume queued agent with fresh file state
4. Update progress display to show queued status

### Step 7: Handle Failures

If a task fails:

1. **Pause execution** of dependent tasks
2. Show error:
   ```
   ## Task [N] Failed

   Error: [error message]

   Dependent tasks affected:
   - Task [X]: [description]
   - Task [Y]: [description]

   Options:
   1. Retry - Attempt Task [N] again
   2. Skip - Skip Task [N] and all dependents
   3. Abort - Stop all execution, keep changes made so far
   ```
3. Wait for user decision via AskUserQuestion
4. Execute chosen option

### Step 8: Summary & Verification

After all waves complete:

```
## Swarm Complete

### Changes Made
- [file1]: [what was done]
- [file2]: [what was done]
- ...

### Tasks Summary
| Task | Status | Files Modified |
|------|--------|----------------|
| 1. [desc] | Complete | [files] |
| 2. [desc] | Complete | [files] |
| 3. [desc] | Skipped | - |
| ... | ... | ... |

### Next Steps
Would you like to:
1. Run role_based_review on all changes
2. Run tests (if available)
3. Done - no verification needed
```

Use AskUserQuestion to present these options.

## Progress Visualization

### Checkpoint-Based Progress

Each agent task has 3 phases:

| Phase | Progress | Checkpoint Marker |
|-------|----------|-------------------|
| Reading files | 0% → 33% | `[CHECKPOINT: READ_FILES]` |
| Planning changes | 33% → 66% | `[CHECKPOINT: PLAN_CHANGES]` |
| Applying changes | 66% → 100% | `[CHECKPOINT: APPLY_CHANGES]` |

### Progress Snapshot Format

Print every 10-15 seconds during execution:

```
## Swarm Progress [HH:MM:SS]

Task 1 [████████████████████] 100% - Complete
Task 2 [████████████░░░░░░░░]  66% - Planning changes
Task 3 [████░░░░░░░░░░░░░░░░]  33% - Reading files
Task 4 [░░░░░░░░░░░░░░░░░░░░]   0% - Queued (waiting on Task 2)
Task 5 [░░░░░░░░░░░░░░░░░░░░]   -  - Wave 2 (pending)

Wave 1: 1/4 complete | Wave 2: Pending
```

### TodoWrite Integration

Maintain parallel todo list for detailed tracking:

```
[x] Task 1: Create user model - COMPLETE
[→] Task 2: Add validation - PLANNING CHANGES (66%)
[→] Task 3: Create routes - READING FILES (33%)
[ ] Task 4: Add service layer - QUEUED
[ ] Task 5: Connect routes to service - WAVE 2
```

The `activeForm` field shows current phase (e.g., "Planning changes for validation").

### Monitoring Implementation

```
1. Launch agents with run_in_background=true
2. Store output_file paths for each agent
3. Loop every 10-15 seconds:
   a. For each running agent:
      - TaskOutput with block=false, timeout=1000
      - Parse output for [CHECKPOINT: *] markers
      - Parse for [TASK_COMPLETE] marker
   b. Update TodoWrite with current statuses
   c. Print progress snapshot
   d. Check if wave is complete
4. When wave completes, start next wave
5. Print final summary when all waves done
```

## Error Handling

### Missing Task Description
If no task provided:
- Ask: "Please describe the task you want to execute."

### Decomposition Failure
If task cannot be meaningfully decomposed:
- "This task doesn't benefit from swarm decomposition. Would you like to execute it directly instead?"

### Agent Timeout
If an agent doesn't respond within 10 minutes:
- Mark task as failed
- Trigger failure handling flow (Step 7)

### All Tasks in Single Wave
If decomposition results in all tasks being independent:
- This is fine - execute all in Wave 1
- Still show task graph for approval

### Single Task Result
If decomposition results in only 1 task:
- "This task doesn't need swarm decomposition. Executing directly..."
- Execute without swarm overhead

## Specialized Agent Types

By default, all tasks use `general-purpose` agents. However, you can leverage specialized agents for specific task types:

### Available Specialized Agents

| Agent Type | Best For | Example Use |
|------------|----------|-------------|
| `general-purpose` | Most implementation tasks | Creating files, writing code |
| `feature-dev:code-reviewer` | Code review tasks | Security audit of new auth code |
| `Explore` | Research/discovery tasks | Finding related files before modification |
| `Plan` | Architecture decisions | Designing component structure |

### How Agent Types Are Assigned

1. **Default**: All tasks use `general-purpose` unless specified otherwise
2. **User override**: Specify `--agent <type>` to change the default for all tasks
3. **Per-task override**: In the "modify" step, request specific agent types for specific tasks
4. **Auto-suggestion**: If a task appears to match a specialized agent (e.g., "review security of..."), Claude will ask:
   ```
   Task 4 looks like a code review task. Use specialized reviewer agent?
   - Yes, use feature-dev:code-reviewer
   - No, keep general-purpose
   ```

### Example: Mixed Agent Types

```
/parallel_claudes:swarm add user auth with security review

## Task Breakdown

### Wave 1
- [1] Create User model
  Agent: general-purpose
- [2] Create auth routes
  Agent: general-purpose

### Wave 2
- [3] Security review of auth implementation (depends on: 1, 2)
  Agent: feature-dev:code-reviewer ← Will you approve this specialized agent?
- [4] Write tests (depends on: 1, 2)
  Agent: general-purpose
```

## Token Efficiency Rules
<!-- SYNC: token-efficiency-swarm -->

1. **Parallel agent launch**: Launch all wave agents in ONE message
2. **Compressed context option**: Use `--context compressed` for independent tasks
3. **Skip trivial tasks**: Don't swarm tasks under 20 lines
4. **Efficient monitoring**: Use non-blocking TaskOutput checks
5. **Scope constraints**: Each agent only reads/writes files in its scope

## Execution, Not Deliberation
<!-- SYNC: execution-disclaimer -->

Unlike other parallel_claudes commands that follow a **deliberation-first** pattern, swarm **executes immediately** after you approve the task breakdown. There is no intermediate consensus-building or review step.

**Why this design?**
- Complex multi-part tasks benefit more from parallel execution than deliberation
- MECE decomposition ensures tasks are independent and won't conflict
- You review and approve the task graph before any execution begins
- Post-completion verification (role_based_review or tests) catches issues

**When NOT to use swarm:**
- Simple single-file changes (just ask Claude directly)
- Changes requiring human review before each step (use deliberation commands)
- Tasks where file dependencies are unclear upfront
- Exploratory work where the approach isn't well-defined
- **Small tasks where latency matters**: Subagents have startup overhead (~5-15 seconds each). For tasks that would take <30 seconds to do directly, the coordination cost exceeds the parallelization benefit. Use swarm for **larger tasks** where parallel execution saves meaningful time.

## Example Usage

**Complex feature:**
```
/parallel_claudes:swarm add user authentication with JWT tokens, including user model, auth routes, middleware, and tests
```

**Multi-file refactoring:**
```
/parallel_claudes:swarm rename PaymentService to BillingService across the entire codebase
```

**With flags:**
```
/parallel_claudes:swarm -n 3 --model opus add a complete CRUD API for products with validation
```

**Compressed context for independent tasks:**
```
/parallel_claudes:swarm --context compressed create unit tests for all utility functions
```
