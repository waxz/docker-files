#!/usr/bin/env bash
set -e

SESSION=docker

# Ensure tmux session exists
if command -v tmux >/dev/null 2>&1; then
    tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION"
fi

# If arguments were passed (docker exec or docker run cmd)
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# Non-interactive environment (CI / GitHub Actions)
if [ ! -t 0 ]; then
    exec tail -f /dev/null
fi

# Interactive shell
if command -v tmux >/dev/null 2>&1; then
    exec tmux attach-session -t "$SESSION"
else
    exec bash
fi