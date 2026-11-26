# Plan-keeping rules (from the pass_off plugin)

A hook reloads the active plan into context after compaction and on resume. It finds the plan through a marker file, so keep the marker and the plan current.

- When you start work from a plan file, or switch to a different one, write its path to `.claude/active-plan` in the project root. One line, relative to the project root.
- If you find a marker at the start of work, read the plan it names before acting.
- As you finish each step, mark it done in the plan file. Do this as you go. Compaction gives no warning.
- When you or the user make a decision that changes the plan, record the decision and its reason in the plan file.
- When the plan is complete or abandoned, delete `.claude/active-plan` and `.claude/active-handoff`.
- `/pass_off` writes a handoff file with the tactical state and points `.claude/active-handoff` at it. The hook reloads that file too. The plan holds strategy. The handoff holds the state of one moment, so check it against the code before trusting it.

These rules apply only when the work follows a plan file. Sessions without one need no marker.
