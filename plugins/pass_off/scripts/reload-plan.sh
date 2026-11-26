#!/bin/bash
# SessionStart hook: reload the active plan, or the latest handoff, after
# compaction or resume.
#
# usage:  reload-plan.sh [plan|handoff]     (default: plan)
#
# A project names each file in a one-line marker in its root:
#   .claude/active-plan      the plan in progress: strategy, steps, decisions
#   .claude/active-handoff   the latest /pass_off handoff: tactical state
# The line is the file's path, absolute or relative to the project root. This
# script finds the marker and prints the file to stdout, which Claude Code adds
# to the new context. It only reads, and it always exits 0 so it can never
# block a session.
#
# stdin:  the hook's JSON (uses .cwd and .source)
# env:    RELOAD_PLAN_MAX_CHARS      files larger than this print as an excerpt
#         RELOAD_PLAN_EXCERPT_CHARS  size of that excerpt
# tests:  bash tests/test-reload-plan.sh  (from the plugin folder)
#
# Claude Code caps each hook's stdout at 10,000 characters. Past the cap it
# keeps only the first 2,000 and does not ask Claude to read the rest. Both
# limits below keep the total output under the cap, so the read instruction
# always arrives. Plan and handoff run as two hook commands, so each gets its
# own cap.

MAX_CHARS="${RELOAD_PLAN_MAX_CHARS:-9000}"
EXCERPT_CHARS="${RELOAD_PLAN_EXCERPT_CHARS:-6000}"

kind="plan"
[ "${1:-}" = "handoff" ] && kind="handoff"

input="$(cat 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
source_event="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)"
[ -d "$cwd" ] || cwd="$PWD"
[ -n "$source_event" ] || source_event="session start"

# Walk up from the session's folder to the nearest marker. The home folder and
# the filesystem root count only when the session started there, so a stray
# marker in either cannot attach a file to every project below it.
marker_name=".claude/active-$kind"
root=""
dir="$cwd"
while :; do
  if [ -f "$dir/$marker_name" ]; then
    root="$dir"
    break
  fi
  parent="$(dirname "$dir")"
  if [ "$parent" = "$dir" ] || [ "$parent" = "$HOME" ] || [ "$parent" = "/" ]; then
    break
  fi
  dir="$parent"
done
[ -n "$root" ] || exit 0

# The file path is the marker's first non-blank line, trimmed.
target="$(grep -m1 '[^[:space:]]' "$root/$marker_name" 2>/dev/null |
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$target" ] || exit 0

case "$target" in
  /*) path="$target" ;;
  *) path="$root/$target" ;;
esac

if [ ! -f "$path" ]; then
  echo "Warning: $root/$marker_name names the $kind file \"$target\", which does not exist at $path. Ask the user which $kind is current before relying on one."
  exit 0
fi

size="$(wc -c < "$path" | tr -d ' ')"

if [ "$kind" = "plan" ]; then
  echo "# Active plan (reloaded after $source_event)"
  echo
  echo "This session is working from the plan file below. It is the source of truth"
  echo "for the goal, the steps, and the decisions made so far. Continue from the"
  echo "first unfinished step, and keep the file current as you work."
  echo
  echo "Plan file: $path"
else
  # A handoff describes one moment, so say how old it is.
  mtime="$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null)"
  written="unknown time"
  if [ -n "$mtime" ]; then
    stamp="$(date -r "$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    mins=$(( ($(date +%s) - mtime) / 60 ))
    if [ "$mins" -lt 60 ]; then age="$mins minutes ago"
    elif [ "$mins" -lt 2880 ]; then age="$((mins / 60)) hours ago"
    else age="$((mins / 1440)) days ago"; fi
    written="$stamp ($age)"
  fi
  echo "# Latest handoff (reloaded after $source_event)"
  echo
  echo "Written: $written"
  echo
  echo "The handoff below records the tactical state at the moment it was written:"
  echo "what was in flight, what was tried, and the next action. The active plan"
  echo "holds the strategy. Work may have happened since. Where the handoff"
  echo "conflicts with the plan or with the code as it stands, trust the newer one."
  echo
  echo "Handoff file: $path"
fi
echo

if [ "$size" -gt "$MAX_CHARS" ]; then
  echo "The $kind is $size characters, too large to print here in full. Read it in full before your next action. Its opening section follows."
  echo
  # Whole lines only, up to the excerpt size.
  awk -v max="$EXCERPT_CHARS" '{ n += length($0) + 1; if (n > max) exit; print }' "$path"
  echo
  echo "[Excerpt ends. The rest is in $path]"
else
  cat "$path"
fi

exit 0
