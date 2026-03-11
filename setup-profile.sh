#!/bin/bash

BASHRC_CONTENT='
# Docker Shell Configuration
export DOCKER_SHELL_COMPOSE_FILE_DEFAULT="/mnt/c/Users/$USER/dev/shell-mcp-server/docker/docker-compose.yml"
export DOCKER_SHELL_SERVICE_DEFAULT="drun"
export DOCKER_SANDBOX_HOST_ROOT_DEFAULT="/mnt/c/Users/$USER/dev/repo"
export DOCKER_SANDBOX_WORKDIR_DEFAULT="/mnt/c/Users/$USER/dev/repo"

drun_rm(){
    export DOCKER_SHELL_COMPOSE_FILE="${DOCKER_SHELL_COMPOSE_FILE_OVERRIDE:-$DOCKER_SHELL_COMPOSE_FILE_DEFAULT}"
    export DOCKER_SHELL_SERVICE="${DOCKER_SHELL_SERVICE_OVERRIDE:-$DOCKER_SHELL_SERVICE_DEFAULT}"
    export DOCKER_SANDBOX_HOST_ROOT="${DOCKER_SANDBOX_HOST_ROOT_OVERRIDE:-$DOCKER_SANDBOX_HOST_ROOT_DEFAULT}"
    export DOCKER_SANDBOX_WORKDIR="${DOCKER_SANDBOX_WORKDIR_OVERRIDE:-$DOCKER_SANDBOX_WORKDIR_DEFAULT}"

    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi
    docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" kill "$DOCKER_SHELL_SERVICE"
    docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" rm "$DOCKER_SHELL_SERVICE"
    return 0
}

drun() {
    export DOCKER_SHELL_COMPOSE_FILE="${DOCKER_SHELL_COMPOSE_FILE_OVERRIDE:-$DOCKER_SHELL_COMPOSE_FILE_DEFAULT}"
    export DOCKER_SHELL_SERVICE="${DOCKER_SHELL_SERVICE_OVERRIDE:-$DOCKER_SHELL_SERVICE_DEFAULT}"
    export DOCKER_SANDBOX_HOST_ROOT="${DOCKER_SANDBOX_HOST_ROOT_OVERRIDE:-$DOCKER_SANDBOX_HOST_ROOT_DEFAULT}"
    export DOCKER_SANDBOX_WORKDIR="${DOCKER_SANDBOX_WORKDIR_OVERRIDE:-$DOCKER_SANDBOX_WORKDIR_DEFAULT}"

    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi
    
    if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
        echo "Service $DOCKER_SHELL_SERVICE not running. Starting..."
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" up -d --quiet-pull --no-recreate --remove-orphans "$DOCKER_SHELL_SERVICE" > /dev/null 2>&1
        
        if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
            echo "Error: Service $DOCKER_SHELL_SERVICE failed to start. Exit." >&2
            return 1
        fi
    fi

    if [ $# -eq 0 ]; then
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" /usr/local/bin/entrypoint.sh
    else
        local cmd="$*"
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" bash -c "source /etc/bash.bashrc 2>/dev/null; $cmd"
    fi
}

export -f drun
export -f drun_rm
'

BASHRC="$HOME/.bashrc"

if [ -f "$BASHRC" ]; then
    if grep -q 'DOCKER_SHELL_COMPOSE_FILE_DEFAULT' "$BASHRC"; then
        echo "Docker Shell configuration already exists in ~/.bashrc"
        echo "Please manually edit ~/.bashrc to update."
        exit 0
    fi
fi

echo "$BASHRC_CONTENT" >> "$BASHRC"
echo "Docker Shell configuration added to ~/.bashrc"
