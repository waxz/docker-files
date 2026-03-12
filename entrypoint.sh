#!/usr/bin/env bash
set -e

# 1. Virtual Env Setup (Optimized: only runs if missing)
if [ ! -d "/opt/.venv/bin" ]; then
    echo "Initializing virtual environment..."
    uv venv /opt/.venv -p 3.12
fi

set -a            # Same as 'set -o allexport'
source /opt/.venv/bin/activate
set +a            # Disable auto-export

# 2. Background Tasks
# Start your custom script in the background immediately
if [ ! -f "/opt/.stated.lock" ]; then
    echo "Initializing start.sh..."
    touch /opt/.stated.lock
    # Run in background so it doesn't block the entrypoint
    nohup bash /opt/shell/start.sh > /var/log/start_sh.log 2>&1 &
fi

# 3. Tmux Session (Optional background helper)
SESSION="docker"
if command -v tmux >/dev/null 2>&1; then
    tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION"
fi

# 4. Handle Execution Logic
if [ "$#" -gt 0 ]; then
    # If arguments are passed (via drun <cmd>), execute them
    exec "$@"
else
    # IMPORTANT: Keep-alive for 'drun' (PowerShell) to see a "running" status
    echo "Container ready. Staying alive..."
    
    # If it's an interactive terminal, drop to bash
    if [ -t 0 ]; then
        exec bash
    else
        # If no TTY (background), wait forever
        tail -f /dev/null
    fi
fi
