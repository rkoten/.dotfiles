#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <session-name>" >&2
    exit 1
fi

SESSION_NAME="$1"

# Check if already inside the target session
if [ -n "${TMUX:-}" ] && [ "$(tmux display-message -p '#S')" = "$SESSION_NAME" ]; then
    echo "Already in tmux session: $SESSION_NAME"
    exit 0
fi

# Check if session exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if [ -n "${TMUX:-}" ]; then
        tmux switch-client -t "$SESSION_NAME"
    else
        tmux attach-session -t "$SESSION_NAME"
    fi
else
    if [ -n "${TMUX:-}" ]; then
        tmux new-session -d -s "$SESSION_NAME"
        tmux switch-client -t "$SESSION_NAME"
    else
        tmux new-session -s "$SESSION_NAME"
    fi
fi
