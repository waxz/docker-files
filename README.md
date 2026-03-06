# docker compose for safe shell execution


### build

```powershell
docker compose kill
docker compose rm
# docker compose build


# check

docker compose --env-file .env.windows config

docker compose --env-file .env.wsl config


# on winodws
docker compose --env-file .env.windows build
# on wsl
docker compose --env-file .env.wsl build
 


```

### run


```powershell


docker compose --env-file .env.windows run --entrypoint bash drun
docker compose --env-file .env.windows exec  drun bash -ic "uv pip uninstall mcp"

docker compose --env-file .env.wsl run --entrypoint bash drun
docker compose --env-file .env.wsl exec  drun bash -ic "uv pip uninstall mcp"



docker compose run --rm drun bash -c "ls && echo hello >> log.txt"
docker compose run --rm drun bash -ic "mkdir -p test && touch package.json && cd test && npm i"
docker compose run --rm -q --remove-orphans drun bash  -ic "mkdir -p test && touch package.json && cd test && npm i"
```

### Use on Windows


- create powershell profile

```powershell
notepad $PROFILE

```

- add 'drun' to profile

```
$Env:DOCKER_SHELL_CONFIG = "$HOME\dev\shell-mcp-server\docker"
$Env:DOCKER_SHELL_ENV = "windows"
$Env:DOCKER_SHELL_ENV_FILE = "$Env:DOCKER_SHELL_CONFIG\.env.$Env:DOCKER_SHELL_ENV"
$Env:DOCKER_SHELL_COMPOSE_FILE = "$Env:DOCKER_SHELL_CONFIG\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE = "drun"

function drun {
    if (-not (Test-Path $Env:DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "Could not find config at: $DOCKER_SHELL_COMPOSE_FILE"
        return
    }

    # 1. Check if the specific service is already running
    # --filter "status=running" and --quiet returns the container ID if it exists
    $isRunning = docker compose -f $Env:DOCKER_SHELL_COMPOSE_FILE --env-file $Env:DOCKER_SHELL_ENV_FILE ps --filter "status=running" --format "{{.Service}}" | Select-String -Pattern "^$Env:DOCKER_SHELL_SERVICE$"

    if (-not $isRunning) {
        Write-Host "Service $Env:DOCKER_SHELL_SERVICE not running. Starting..." -ForegroundColor Cyan
        docker compose -f $Env:DOCKER_SHELL_COMPOSE_FILE --env-file $Env:DOCKER_SHELL_ENV_FILE up -d --quiet-pull --no-recreate $Env:DOCKER_SHELL_SERVICE > $null 2>&1
    }

    # 2. Execute command or enter shell
    if ($args.Count -eq 0) {
        # Interactive entry (Tmux entrypoint)
        docker compose -f $Env:DOCKER_SHELL_COMPOSE_FILE  --env-file $Env:DOCKER_SHELL_ENV_FILE exec $Env:DOCKER_SHELL_SERVICE /usr/local/bin/entrypoint.sh
    } else {
        # Non-interactive command string
        $cmd = $args -join ' '
        docker compose -f $Env:DOCKER_SHELL_COMPOSE_FILE --env-file $Env:DOCKER_SHELL_ENV_FILE exec $Env:DOCKER_SHELL_SERVICE bash -c "source /etc/bash.bashrc 2>/dev/null; $cmd"
    }
}

```


- use drun

```powershell
drun "uname -a"

```

### Use on lunix

```

# Configuration variables
DOCKER_SHELL_CONFIG="/mnt/c/Users/$USER/dev/shell-mcp-server/docker"
DOCKER_SHELL_ENV="wsl"

DOCKER_SHELL_COMPOSE_FILE="$DOCKER_SHELL_CONFIG/docker-compose.yml"
DOCKER_SHELL_ENV_FILE="$DOCKER_SHELL_CONFIG/.env.$DOCKER_SHELL_ENV"

DOCKER_SHELL_SERVICE="drun" 

drun() {
    # Check if config exists
    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi

    # 1. Check if the service is already running
    # -q returns 0 if found, 1 if not
    if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
        echo "Service $DOCKER_SHELL_SERVICE not running. Starting..."
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" --env-file "$DOCKER_SHELL_ENV_FILE" up -d --quiet-pull --no-recreate "$DOCKER_SHELL_SERVICE" > /dev/null 2>&1
    fi

    # 2. Exec into the container
    if [ $# -eq 0 ]; then
        # Interactive entry (uses the tmux entrypoint)
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" --env-file "$DOCKER_SHELL_ENV_FILE" exec "$DOCKER_SHELL_SERVICE" /usr/local/bin/entrypoint.sh
    else
        # Join arguments into a single command string
        local cmd="$*"
        # Source bashrc to ensure uv/pip/aliases are loaded for the command
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" --env-file "$DOCKER_SHELL_ENV_FILE" exec "$DOCKER_SHELL_SERVICE" bash -c "source /etc/bash.bashrc 2>/dev/null; $cmd"
    fi
}

```