#!/bin/bash
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

tmux has-session -t docker 2>/dev/null || tmux new-session -d -s docker

if [ ! -t 0 ]; then
    tail -f /dev/null
else
    exec tmux attach-session -t docker
fi