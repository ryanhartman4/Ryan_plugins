#!/bin/bash
# Tests for scripts/reload-plan.sh. Run from the plugin folder: bash tests/test-reload-plan.sh
# Each case builds a throwaway project, feeds the hook's stdin JSON, and checks stdout.

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/reload-plan.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# A fake home keeps the real one out of the tests.
export HOME="$TMP/home"
mkdir -p "$HOME"

run() { # run <cwd> [source]  -> stdout of the hook
  jq -n --arg cwd "$1" --arg source "${2:-compact}" \
    '{session_id:"t", hook_event_name:"SessionStart", cwd:$cwd, source:$source}' |
    bash "$SCRIPT"
}

check() { # check <name> <condition exit code>
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); echo "ok   $1"
  else fail=$((fail + 1)); echo "FAIL $1"; fi
}

has() { printf '%s' "$1" | grep -qF -- "$2"; }

project() { # project <name> -> path of a new project with a marker and a plan
  local p="$HOME/work/$1"
  mkdir -p "$p/.claude" "$p/docs/plans"
  echo "STEP-ONE-SENTINEL" > "$p/docs/plans/plan.md"
  echo "docs/plans/plan.md" > "$p/.claude/active-plan"
  echo "$p"
}

# 1. No marker: prints nothing.
mkdir -p "$HOME/work/empty"
out="$(run "$HOME/work/empty")"; rc=$?
[ -z "$out" ] && [ $rc -eq 0 ]; check "no marker prints nothing" $?

# 2. Marker and plan: prints the plan text, its absolute path, and the source.
p="$(project basic)"
out="$(run "$p" compact)"
has "$out" "STEP-ONE-SENTINEL" && has "$out" "$p/docs/plans/plan.md" && has "$out" "reloaded after compact"
check "prints plan, path, and source" $?

# 3. Session started in a subfolder: walks up to the marker.
p="$(project nested)"
mkdir -p "$p/src/deep/er"
out="$(run "$p/src/deep/er")"
has "$out" "STEP-ONE-SENTINEL"; check "walks up from a subfolder" $?

# 4. Marker points at a missing file: one warning that names the path.
p="$(project missing)"
echo "docs/plans/gone.md" > "$p/.claude/active-plan"
out="$(run "$p")"; rc=$?
has "$out" "docs/plans/gone.md" && has "$out" "does not exist" && [ $rc -eq 0 ]
check "missing plan file warns" $?

# 5. Oversized plan: prints the path, a read instruction, and the opening lines only.
p="$(project big)"
printf 'HEAD-SENTINEL\nsecond line\nTAIL-SENTINEL\n' > "$p/docs/plans/plan.md"
out="$(RELOAD_PLAN_MAX_CHARS=5 RELOAD_PLAN_EXCERPT_CHARS=30 run "$p")"
has "$out" "$p/docs/plans/plan.md" && has "$out" "Read it in full" &&
  has "$out" "HEAD-SENTINEL" && ! has "$out" "TAIL-SENTINEL"
check "oversized plan prints an excerpt" $?

# 5b. With default limits, output stays under Claude Code's 10,000 character cap
#     for a plan just under the limit and for a huge one.
p="$(project capsmall)"
awk 'BEGIN { for (i = 0; i < 120; i++) print "a line of plan text that is seventy-four characters long, padded out here." }' > "$p/docs/plans/plan.md"
small="$(run "$p" | wc -c | tr -d ' ')"
p="$(project caphuge)"
awk 'BEGIN { for (i = 0; i < 2000; i++) print "a line of plan text that is seventy-four characters long, padded out here." }' > "$p/docs/plans/plan.md"
huge="$(run "$p" | wc -c | tr -d ' ')"
[ "$small" -gt 8000 ] && [ "$small" -lt 10000 ] && [ "$huge" -lt 10000 ]
check "output stays under the 10,000 cap (small=$small huge=$huge)" $?

# 6. Stray marker in the home folder: ignored for projects below it.
mkdir -p "$HOME/.claude" "$HOME/work/plain"
echo "HOME-PLAN-SENTINEL" > "$HOME/home-plan.md"
echo "home-plan.md" > "$HOME/.claude/active-plan"
out="$(run "$HOME/work/plain")"
[ -z "$out" ]; check "home marker ignored from a project" $?

# 7. Session started in the home folder itself: its marker counts.
out="$(run "$HOME")"
has "$out" "HOME-PLAN-SENTINEL"; check "home marker used from home" $?
rm -rf "$HOME/.claude" "$HOME/home-plan.md"

# 8. Paths with spaces.
p="$HOME/work/Application Support/my proj"
mkdir -p "$p/.claude" "$p/my plans"
echo "SPACE-SENTINEL" > "$p/my plans/the plan.md"
echo "my plans/the plan.md" > "$p/.claude/active-plan"
out="$(run "$p")"
has "$out" "SPACE-SENTINEL"; check "paths with spaces" $?

# 9. Whitespace-only marker: prints nothing.
p="$(project blank)"
printf '   \n\n' > "$p/.claude/active-plan"
out="$(run "$p")"
[ -z "$out" ]; check "blank marker prints nothing" $?

# 10. Marker with padding and a trailing blank line still resolves.
p="$(project padded)"
printf '\n  docs/plans/plan.md  \n\n' > "$p/.claude/active-plan"
out="$(run "$p")"
has "$out" "STEP-ONE-SENTINEL"; check "padded marker resolves" $?

# 11. Absolute path in the marker.
p="$(project absolute)"
echo "$p/docs/plans/plan.md" > "$p/.claude/active-plan"
out="$(run "$p")"
has "$out" "STEP-ONE-SENTINEL"; check "absolute marker path" $?

# 12. Malformed stdin: falls back to the shell's folder, exits 0.
p="$(project badjson)"
out="$(cd "$p" && echo 'not json' | bash "$SCRIPT")"; rc=$?
has "$out" "STEP-ONE-SENTINEL" && [ $rc -eq 0 ]; check "malformed stdin falls back to PWD" $?

# 13. Empty stdin in a folder with no marker: silent, exits 0.
out="$(cd "$HOME/work/empty" && bash "$SCRIPT" < /dev/null)"; rc=$?
[ -z "$out" ] && [ $rc -eq 0 ]; check "empty stdin is silent" $?

# 14. Marker pointing at a folder: warns, prints no listing.
p="$(project isdir)"
echo "docs/plans" > "$p/.claude/active-plan"
out="$(run "$p")"; rc=$?
has "$out" "does not exist" && [ $rc -eq 0 ]; check "marker pointing at a folder warns" $?

# --- Handoff mode -----------------------------------------------------------

run_handoff() { # run_handoff <cwd> [source]
  jq -n --arg cwd "$1" --arg source "${2:-compact}" \
    '{session_id:"t", hook_event_name:"SessionStart", cwd:$cwd, source:$source}' |
    bash "$SCRIPT" handoff
}

# 15. Handoff marker: prints the handoff, its path, its age, and the source.
p="$(project handoff)"
echo "HANDOFF-SENTINEL" > "$p/docs/HANDOFF_1.md"
echo "docs/HANDOFF_1.md" > "$p/.claude/active-handoff"
out="$(run_handoff "$p" resume)"
has "$out" "HANDOFF-SENTINEL" && has "$out" "$p/docs/HANDOFF_1.md" &&
  has "$out" "Latest handoff (reloaded after resume)" && has "$out" "0 minutes ago"
check "handoff mode prints handoff with age" $?

# 16. The two modes stay separate: each prints only its own file.
! has "$out" "STEP-ONE-SENTINEL" && ! has "$(run "$p")" "HANDOFF-SENTINEL"
check "plan and handoff modes stay separate" $?

# 17. Handoff mode with no handoff marker: silent, even when a plan marker exists.
p="$(project planonly)"
out="$(run_handoff "$p")"; rc=$?
[ -z "$out" ] && [ $rc -eq 0 ]; check "handoff mode silent without its marker" $?

# 18. An old handoff reports its age in days.
p="$(project oldhandoff)"
echo "OLD-SENTINEL" > "$p/docs/HANDOFF_old.md"
touch -t 202001010000 "$p/docs/HANDOFF_old.md"
echo "docs/HANDOFF_old.md" > "$p/.claude/active-handoff"
out="$(run_handoff "$p")"
has "$out" "2020-01-01" && has "$out" "days ago"; check "old handoff shows its age in days" $?

# 19. Missing handoff file: warns and names the kind.
p="$(project nohandoff)"
echo "docs/HANDOFF_gone.md" > "$p/.claude/active-handoff"
out="$(run_handoff "$p")"
has "$out" "handoff file" && has "$out" "does not exist"; check "missing handoff file warns" $?

# 20. A huge handoff stays under the 10,000 character cap.
p="$(project hugehandoff)"
awk 'BEGIN { for (i = 0; i < 2000; i++) print "a line of handoff text, seventy-four characters long, padded out to here." }' > "$p/docs/HANDOFF_big.md"
echo "docs/HANDOFF_big.md" > "$p/.claude/active-handoff"
n="$(run_handoff "$p" | wc -c | tr -d ' ')"
[ "$n" -lt 10000 ]; check "huge handoff stays under the cap (n=$n)" $?

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
