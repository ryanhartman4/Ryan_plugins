# Pass Off

Keep a plan and a handoff alive across compaction and across sessions.

Compaction replaces a conversation with a summary. The summary drops the sentence that said which plan file the work follows, so the new context starts cold while the plan sits on disk, unread. This plugin stores that pointer in a file and reloads the plan from it.

## What it does

- **Reloads the plan.** After every compaction and every resume, a hook prints the active plan into the new context.
- **Reloads the latest handoff.** The same hook prints the most recent handoff, with its age.
- **Writes handoffs.** `/pass_off:pass_off` writes a tactical handoff from the conversation and tests it with a reader that has no context.
- **States the rules.** At every session start, a hook tells Claude to keep the plan and its marker current.

## Two files, two jobs

| | Plan | Handoff |
|---|---|---|
| Holds | Strategy: goal, steps, decisions that shape them | Tactical state of one moment |
| Lifespan | The whole project | Until the next handoff replaces it |
| Marker | `.claude/active-plan` | `.claude/active-handoff` |
| Written by | Claude, as work proceeds | `/pass_off:pass_off` |

Each marker sits in the project root and holds one line: the file's path, relative to that root. The markers are local state. Add them to your global gitignore:

```bash
printf '**/.claude/active-plan\n**/.claude/active-handoff\n' >> ~/.config/git/ignore
```

## Installation

```
/plugin marketplace add ryanhartman4/Ryan_plugins
/plugin install pass_off@Ryan_plugins
```

The hook needs `bash` and `jq`.

## The command

`/pass_off:pass_off` runs six steps:

1. Finds the active plan.
2. Marks finished steps and strategy-level decisions in the plan.
3. Rereads the conversation for what git cannot record: decisions with reasons, rejected approaches, the user's corrections and exact requirements, what was in flight, what is verified and what is assumed.
4. Writes `docs/HANDOFF_<date_time>.md` (or the project root when there is no `docs/`), with a "Where we are" block first, and points `.claude/active-handoff` at it.
5. Gives a fresh subagent only the plan and the handoff, then asks it for the goal, the next action, the reasoning, what to avoid redoing, and what it would ask the user. Wrong answers mark gaps, and the command fixes them.
6. Reports the file's location, what the reader got wrong, and any open questions.

Run it before you compact by hand or close a session.

## The hook

`scripts/reload-plan.sh` runs on the `SessionStart` event for the `compact` and `resume` sources, once for the plan and once for the handoff.

- It walks up from the session's folder to the nearest marker. A marker in the home folder counts only for sessions started in the home folder.
- No marker: it prints nothing.
- A marker that names a missing file: it prints a one-line warning.
- Claude Code caps each hook's output at 10,000 characters and silently truncates past that. So the script prints files up to 9,000 characters in full. For a longer file it prints the path, an instruction to read the whole file, and the first 6,000 characters. Put current state at the top of long plans.
- A handoff arrives with its age and a note to trust the newer record where it conflicts with the plan or the code.
- It only reads, and it always exits 0.

## Tests

```bash
bash tests/test-reload-plan.sh
```

Run from the plugin folder. Twenty-one cases cover the paths above.

## Limits

- One active plan per project folder. Two sessions in the same folder share the marker, and the last one to write it wins. Git worktrees each get their own.
- The reload fires on compaction and resume. A brand-new session gets the rules and reads the marker when it starts plan work.
