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
Invalid --context: [value]. Valid options: full, compressed. Using default (compressed).
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
- **Research tasks**: Output is findings/analysis text. Agent writes findings to `.swarm/task_{N}_findings.md`; downstream tasks read that file directly.

For research tasks that feed into later waves, consider:
- Is the research actually needed, or can the implementation task do its own quick exploration?
- Research findings are written to handoff files, so downstream tasks read them directly (not through orchestrator)
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

### Step 4: Setup & Permission Warmup

Background agents cannot prompt for permissions interactively. Before launching agents, create the handoff directory and grant Edit permissions.

**Process:**
1. **Create handoff directory**: Run `mkdir -p .swarm` to create the handoff file directory
   - If `.gitignore` exists and doesn't contain `.swarm`, append `.swarm` to it (prevents accidental commits of temp files)
2. Identify unique directories from the task breakdown's file list
3. For each directory, select one existing file that will be modified
4. Display explanation to user:
   ```
   ## Permission Warmup

   Background agents can't request edit permissions interactively.
   I'll make a small no-op edit to these files to grant permission:
   - [file1]
   - [file2]

   **Important:** When prompted, select "Always allow" or "Allow all edits" to grant
   permission for the entire session. This allows background agents to write files.
   ```
5. For each file, make a trivial edit (add a trailing newline, then remove it) using the Edit tool
6. The user selecting "Always allow" grants Edit permission to background agents for the session

**Note:** If all tasks only create new files (no modifications), this step can be skipped since Write permissions for new files don't require warmup.

### Step 5: Execute Waves

**CRITICAL:** Use `run_in_background=true` for all agents to enable progress monitoring.

For each wave:

1. **Pre-wave conflict check**: Verify no file overlaps within the wave
   - If overlap detected: Move conflicting task to next wave or serialize

2. **Launch agents**: In a SINGLE message, launch all wave tasks using Task tool with `subagent_type` set to each task's configured agent type (default: `general-purpose`)

3. **Progress monitoring loop** (every 10-15 seconds) — **MINIMAL CONTEXT**:
   - Use `tail -n 10 <output_file>` (via Bash) to check each agent's recent output
   - **Do NOT use TaskOutput during monitoring**—it pulls full output into context
   - Parse only for checkpoint markers: `[CHECKPOINT: ...]` or `[TASK_COMPLETE]`
   - Update TodoWrite with current status
   - Print progress snapshot (see Progress Visualization below)

4. **Wave completion**: Wait for all wave agents to complete before starting next wave
   - Detect completion by seeing `[TASK_COMPLETE]` in tail output
   - Only then use `TaskOutput` with `block=true` to get the final minimal message

5. **Track completion (minimal context)**: The orchestrator only tracks task status and handoff file paths:
   - Parse the minimal completion message: `[TASK_COMPLETE] Summary: ... Handoff: .swarm/task_{N}_output.md`
   - **Do NOT read handoff file contents**—dependent tasks read them directly
   - Store only: `{task_id, status, summary (1 sentence), handoff_path}`

**File-Based Handoff (Context Efficiency):**
ALL task outputs flow through handoff files, NOT through the orchestrator's context. This prevents context bloat:

```
Orchestrator context (minimal):
├── Task 1: complete | "Created User model" | .swarm/task_1_output.md
├── Task 2: complete | "Added auth routes" | .swarm/task_2_output.md
└── Task 3: running  | ...

Handoff files (full details, read by dependent tasks):
├── .swarm/task_1_output.md  (full reasoning, file changes, notes)
├── .swarm/task_2_output.md  (full reasoning, file changes, notes)
└── ...
```

- Orchestrator receives: 1-sentence summary + file path
- Dependent tasks read: Full handoff files directly via Read tool
- Result: Orchestrator context stays clean regardless of task count

**Agent Prompt Template:**
```
You are executing Task [N] of a swarm operation.

TASK: [description]
TASK TYPE: [implementation | research]

DEPENDENCIES (read these files first):
[For each dependency, list the handoff file to read:]
- Task [X]: Read `.swarm/task_[X]_output.md`

HANDOFF OUTPUT (CRITICAL - keeps orchestrator context clean):
Write ALL your detailed output to `.swarm/task_[N]_output.md`:

```markdown
# Task [N] Output

## Summary
[1-2 sentence summary of what was accomplished]

## Files Changed
- [file1]: [brief description]
- [file2]: [brief description]

## Details
[Full reasoning, decisions made, implementation notes]
[For research: complete findings and analysis]
[For implementation: approach taken, edge cases handled, etc.]
```

Your final message to the orchestrator should be MINIMAL:
```
[TASK_COMPLETE]
Summary: [1 sentence]
Handoff: .swarm/task_[N]_output.md
```

CONSTRAINTS:
- Focus ONLY on this specific task
- Your file scope: [list of files you may create/modify]
- Do not modify files outside your scope
- Apply changes directly - this is an execution task, not review
- Read dependency handoff files—don't redo research that was already done
- Write detailed output to handoff file, NOT to orchestrator

PROGRESS REPORTING (minimal markers only):
- [CHECKPOINT: READ_FILES]
- [CHECKPOINT: PLAN_CHANGES]
- [CHECKPOINT: APPLY_CHANGES]
- [TASK_COMPLETE] Summary: [1 sentence] Handoff: .swarm/task_[N]_output.md

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

### Step 8: Summary, Verification & Cleanup

After all waves complete:

1. **Display summary** (compile from stored task summaries, NOT by reading handoff files):
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

2. **Use AskUserQuestion** to present these options.

3. **Cleanup handoff directory**: After user confirms completion:
   ```bash
   rm -rf .swarm
   ```
   This removes all temporary handoff files. If the user wants to review detailed task outputs later, mention they can skip cleanup, but by default clean up to avoid clutter.

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
      - Bash: tail -n 10 <output_file>  ← MINIMAL context, just last 10 lines
      - Parse for [CHECKPOINT: *] markers
      - Parse for [TASK_COMPLETE] marker
      - Do NOT use TaskOutput during monitoring (pulls full output)
   b. Update TodoWrite with current statuses
   c. Print progress snapshot
   d. Check if wave is complete (all agents show [TASK_COMPLETE])
4. When wave completes:
   a. Use TaskOutput with block=true to get final message (should be minimal)
   b. Extract summary and handoff path from each completed agent
   c. Start next wave
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

| Agent Type | Best For | Agent File |
|------------|----------|------------|
| `general-purpose` | Most implementation tasks | (Anthropic built-in) |
| `security` | Security-focused implementation | `${CLAUDE_PLUGIN_ROOT}/agents/security_agent.md` |
| `performance` | Performance-optimized code | `${CLAUDE_PLUGIN_ROOT}/agents/performance_agent.md` |
| `edge_cases` | Robust error handling | `${CLAUDE_PLUGIN_ROOT}/agents/edge_cases_agent.md` |
| `maintainability` | Clean code focus | `${CLAUDE_PLUGIN_ROOT}/agents/maintainability_agent.md` |
| `testing` | Test writing tasks | `${CLAUDE_PLUGIN_ROOT}/agents/testing_agent.md` |
| `Explore` | Research/discovery tasks | (Anthropic built-in) |
| `Plan` | Architecture decisions | (Anthropic built-in) |

**Note:** External plugin agents (e.g., `feature-dev:code-reviewer`) can also be used if those plugins are installed.

### Local Agent Integration

When a task specifies a local agent type (security, performance, etc.):

1. Read the agent definition from `${CLAUDE_PLUGIN_ROOT}/agents/{type}_agent.md`
2. Include the full agent definition in the task prompt
3. **Add mode override for implementation tasks:**
   ```
   **MODE: IMPLEMENTATION (not review)**

   Apply your specialized expertise to implement this task. Focus on:
   - [security]: Secure coding practices, input validation, auth patterns
   - [performance]: Efficient algorithms, minimal allocations, caching
   - [edge_cases]: Robust error handling, defensive coding, boundary checks
   - [maintainability]: Clean architecture, clear naming, SOLID principles
   - [testing]: Testable structure, dependency injection, clear interfaces

   Output working code, not review findings. Do NOT output CRITICAL/WARNING/SUGGESTION sections.
   ```
4. Launch with `subagent_type=general-purpose` (the agent definition + mode override shapes behavior)

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
  Agent: security ← Uses security_agent.md for security-focused implementation

### Wave 2
- [3] Security review of auth implementation (depends on: 1, 2)
  Agent: security ← Uses security_agent.md for vulnerability analysis
- [4] Write tests (depends on: 1, 2)
  Agent: testing ← Uses testing_agent.md for test writing
```

When a task uses a local agent (security, performance, etc.), the agent file is loaded and included in the task prompt, giving the agent specialized instructions and focus areas.

## Token Efficiency Rules
<!-- SYNC: token-efficiency-swarm -->

1. **Parallel agent launch**: Launch all wave agents in ONE message
2. **Compressed context option**: Use `--context compressed` for independent tasks
3. **Skip trivial tasks**: Don't swarm tasks under 20 lines
4. **Tail-based monitoring**: Use `tail -n 10` on output files, NOT TaskOutput (avoids pulling full output)
5. **File-based handoff**: Agents write to `.swarm/` files; orchestrator only receives 1-line summaries
6. **Direct dependency reads**: Dependent tasks read handoff files directly, not through orchestrator
7. **Scope constraints**: Each agent only reads/writes files in its scope

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
