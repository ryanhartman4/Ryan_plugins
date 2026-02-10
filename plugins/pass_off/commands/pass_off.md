---
description: Create a handoff document with current context and implementation status
allowed-tools: Read, Glob, Grep, Write, Bash(ls:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*)
---

Create a comprehensive handoff document capturing the current state of work.

## Steps

1. **Gather Context**
   - Review any active todos or tasks in progress
   - Check git status for uncommitted changes
   - Review recent git commits relevant to current work
   - Identify files that were recently modified or created

2. **Create Handoff Document**

   Generate a markdown file named `HANDOFF_<timestamp>.md` with:

   ### Document Structure
   ```
   # Handoff Document
   Generated: <current date/time>

   ## Summary
   Brief overview of what was being worked on

   ## Current Status
   - What's completed
   - What's in progress
   - What's blocked or pending

   ## Recent Changes
   - Files modified
   - Key code changes made

   ## Next Steps
   - Recommended actions to continue
   - Open questions or decisions needed

   ## Context & Notes
   - Important context for the next person
   - Any gotchas or things to watch out for
   ```

3. **Save Location**
   - First, check if a `docs/` folder exists in the project root
   - If yes, save there: `docs/HANDOFF_<timestamp>.md`
   - If no `docs/` folder exists, save in the project root

4. **Confirm**
   - Show the user where the file was saved
   - Provide a brief summary of what was captured
