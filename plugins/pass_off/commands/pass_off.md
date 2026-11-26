---
description: Write a tactical handoff file, bring the plan current, and test both with a cold reader
allowed-tools: Read, Glob, Grep, Write, Edit, Agent, Task, Bash(ls:*), Bash(mkdir:*), Bash(date:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*)
---

Hand this work off to a session that has none of this conversation. That session may be this one after compaction, or a new one. It will see two files and nothing else:

- **The plan** holds the strategy: the goal, the steps, and the decisions that shape them. It stays short enough to read whole.
- **The handoff** holds the tactical state of this moment, in as much detail as the next session needs to continue without asking the user anything they already answered.

A hook reloads both after compaction and on resume. It finds them through two marker files in the project root: `.claude/active-plan` and `.claude/active-handoff`. Each marker is one line holding the file's path, relative to the project root.

The source for the handoff is this conversation. Git records what changed. Only the conversation records why, what failed, and what the user said. Capture that.

## Step 1: Find the plan

Read `.claude/active-plan` if it exists, then read the plan it names. If no marker exists and this session worked from a plan file, that file is the plan. If the session had no plan, skip the plan parts of this command and say so in the handoff's header.

## Step 2: Bring the plan current

Edit the plan file. Keep it strategic.

- Mark each finished step done.
- Record any decision that changed the goal, the steps, or their order, with its reason.
- Leave tactical detail out. It goes in the handoff.

Write the plan's path to `.claude/active-plan` if the marker is missing or names a different file.

## Step 3: Gather what the conversation holds

Reread the conversation from the start. Collect:

- decisions and the reason for each
- approaches tried and rejected, and why each failed
- every correction the user gave
- the user's requirements, quoted in their exact words
- what was in flight when this command ran: the file, the function, the half-finished edit, the command that was running
- what is verified, and how, and what is assumed
- anything surprising about the code, the tools, or the environment

Then check the working tree: `git status`, `git diff`, and `git log -n 10`. Use them to confirm the conversation's account. Where they disagree with it, record the disagreement.

## Step 4: Write the handoff

Save to `docs/HANDOFF_<YYYY-MM-DD_HHMM>.md` if a `docs/` folder exists in the project root. Otherwise save in the project root. Get the time from `date`.

"Where we are" comes first, because the hook prints only the opening of a long file. Aim for under 9,000 characters in total so the hook prints the file whole. Go past that when the detail earns it.

```
# Handoff: <the task in a few words>

Written: <date and time> | Plan: <path, or "none"> | Branch: <branch, or "no git">

## Where we are
- Goal: <one sentence>
- Last finished: <the last thing completed and verified>
- In flight: <exactly what was half-done, with file and line>
- Next action: <the first concrete move: the command to run or the edit to make>
- Open questions for the user: <each one, or "none">

## How to resume
<Commands to run, servers to start, logins or env vars needed, and how to
confirm the state matches this file.>

## Decisions and reasons
<Each decision, its reason, and who made it.>

## Tried and rejected
<Each approach, what happened, and why it was dropped. This section stops the
next session from repeating failed work.>

## The user's requirements and corrections
<Direct quotes, each with a line on what it changed.>

## Verified and assumed
<What was checked and how. What is believed and unchecked.>

## Gotchas
<Anything that cost time or would surprise a newcomer.>
```

Write for a reader who lacks all context. Name the file, give the number, show the command. Leave out any section that would be empty. A recap of the diff adds nothing, since the reader can run `git diff`.

Write the handoff's path to `.claude/active-handoff`, replacing what was there. Older handoff files stay on disk as history.

## Step 5: Test with a cold reader

Spawn one subagent on the strongest available model. Give it only the two file paths and this prompt:

> You are taking over this work with no other context. Read the plan and the handoff. Do not read any other file. Then answer: (1) What is the goal? (2) What is your next action, concretely? (3) Why that action, and what was decided or rejected that led to it? (4) What must you avoid redoing? (5) What would you have to ask the user before starting?

Compare its answers with what you know.

- A wrong or vague answer to 1 through 4 marks a gap. Fix the file.
- For 5, a question the conversation already answered marks a gap. Fix the file. A question that is still open belongs under "Open questions for the user".

Run the reader once. Fix what it found without running it again.

## Step 6: Report

Tell the user, in a few lines:

- where the handoff was saved, and which plan it pairs with
- what the cold reader got wrong and what you fixed
- the open questions, if any
- that the session is ready to compact or close
