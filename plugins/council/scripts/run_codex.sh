#!/bin/bash
# Run Codex non-interactively and capture output
# Usage: run_codex.sh "prompt" [working_dir]
#
# Security: Prompt is passed via stdin to avoid leaking to process listings
# Timeouts: Check-in at 5 minutes, hard timeout at 10 minutes

set -euo pipefail

# Input validation
if [[ -z "${1:-}" ]]; then
    echo "Error: Prompt is required" >&2
    echo "Usage: $0 \"prompt\" [working_dir]" >&2
    exit 1
fi

PROMPT="$1"
WORK_DIR="${2:-$(pwd)}"
CHECKIN_TIMEOUT=300   # 5 minutes
HARD_TIMEOUT=600      # 10 minutes

# Validate working directory exists
if [[ ! -d "$WORK_DIR" ]]; then
    echo "Error: Working directory does not exist: $WORK_DIR" >&2
    exit 1
fi

OUTPUT_FILE=$(mktemp)
PID_FILE=$(mktemp)

# Cleanup on exit (success or failure)
cleanup() {
    # Kill codex process if still running
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$OUTPUT_FILE" "$PID_FILE"
}
trap cleanup EXIT

# Run codex in background
echo "$PROMPT" | codex exec --full-auto --skip-git-repo-check -C "$WORK_DIR" -o "$OUTPUT_FILE" - 2>&1 &
CODEX_PID=$!
echo "$CODEX_PID" > "$PID_FILE"

# Wait with check-in
START_TIME=$(date +%s)
CHECKIN_DONE=false

while kill -0 "$CODEX_PID" 2>/dev/null; do
    ELAPSED=$(( $(date +%s) - START_TIME ))

    # Check-in at 5 minutes
    if [[ "$ELAPSED" -ge "$CHECKIN_TIMEOUT" && "$CHECKIN_DONE" == "false" ]]; then
        echo "[Council] Codex is still working (5 min elapsed)... continuing to wait." >&2
        CHECKIN_DONE=true
    fi

    # Hard timeout at 10 minutes
    if [[ "$ELAPSED" -ge "$HARD_TIMEOUT" ]]; then
        echo "[Council] Hard timeout reached (10 min). Terminating Codex." >&2
        kill "$CODEX_PID" 2>/dev/null || true
        # Output any partial results
        if [[ -s "$OUTPUT_FILE" ]]; then
            echo "[Council] Partial output:" >&2
            cat "$OUTPUT_FILE"
        fi
        exit 124  # Standard timeout exit code
    fi

    sleep 2
done

# Check exit status
wait "$CODEX_PID"
EXIT_CODE=$?

if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "[Council] Codex exited with code $EXIT_CODE" >&2
    # Still output any results
    if [[ -s "$OUTPUT_FILE" ]]; then
        cat "$OUTPUT_FILE"
    fi
    exit "$EXIT_CODE"
fi

# Output the result
cat "$OUTPUT_FILE"
