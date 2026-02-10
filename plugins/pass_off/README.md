# Pass Off

Create handoff documents to capture current work state for smooth session transitions.

## Installation

**Step 1:** Add the marketplace
```
/plugin marketplace add ryanhartman4/Ryan_plugins
```

**Step 2:** Install the plugin
```
/plugin install pass_off
```

**Step 3:** Restart Claude Code if prompted

**Step 4:** Start using the command
```
/pass_off
```

## What it Does

- Gathers context from git status, recent commits, and modified files
- Generates a structured handoff document with summary, status, changes, and next steps
- Saves the document to `docs/` (if it exists) or the project root

## How it Works

1. Reviews active todos, uncommitted changes, and recent commits
2. Identifies recently modified or created files
3. Generates a timestamped `HANDOFF_<timestamp>.md` document
4. Saves it and confirms the location

## Commands

### `/pass_off`
Create a handoff document with current context and implementation status.

**Use when:** You're ending a session and want to capture work state for the next session (or another person).

**How it works:**
1. Gathers git status, recent commits, and active tasks
2. Builds a structured markdown document covering summary, status, changes, next steps, and context notes
3. Saves as `HANDOFF_<timestamp>.md` in `docs/` or project root
4. Confirms save location and provides a brief summary

## Document Structure

The generated handoff document includes:

- **Summary** — Brief overview of what was being worked on
- **Current Status** — What's completed, in progress, or blocked
- **Recent Changes** — Files modified and key code changes
- **Next Steps** — Recommended actions and open questions
- **Context & Notes** — Important context and gotchas for the next person
