# docker compose for safe shell execution


## reference
- https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/


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

### source file

```
source ./start-docker.sh

. ./start-docker.ps1

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

$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT = "$HOME\dev\shell-mcp-server\docker\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE_DEFAULT = "drun"
$ENV:DOCKER_SANDBOX_WORKDIR_DEFAULT = "/app/dev/repo"
$ENV:DOCKER_SANDBOX_HOST_ROOT_DEFAULT = "$HOME\dev\repo"


function drun_rm {
    # 1. Resolve Variables (Use Override if present, otherwise fallback to base Env)
    $file    = if ($Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)  { $Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE }  else { $Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT }
    $service = if ($Env:DOCKER_SHELL_SERVICE_OVERRIDE)       { $Env:DOCKER_SHELL_SERVICE_OVERRIDE }       else { $Env:DOCKER_SHELL_SERVICE_DEFAULT }
    $workdir = if ($Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE)     { $Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE }     else { $Env:DOCKER_SANDBOX_WORKDIR_DEFAULT }
    $root    = if ($Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)   { $Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE }   else { $Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT }

    # 2. Print Configuration
    Write-Host "--- Configuration ---" -ForegroundColor Cyan
    Write-Host "COMPOSE_FILE: $file"
    Write-Host "SERVICE:      $service"
    Write-Host "WORKDIR:      $workdir"
    Write-Host "HOST_ROOT:    $root"

    # 3. Validation
    if ([string]::IsNullOrWhiteSpace($file) -or -not (Test-Path $file)) {
        Write-Error "Invalid or missing Compose File: $file"
        return
    }


    # 4. Check status and Cleanup
    $isRunning = docker compose -f $file ps --filter "status=running" --format "{{.Service}}" | 
                 Select-String -Pattern "^$($service)$"

    if ($isRunning) {
        Write-Host "Cleaning up service $service..." -ForegroundColor Yellow
        
        # Combined down command is cleaner than kill + rm
        docker compose -f $file down --volumes --remove-orphans | Out-Null
        
        # Verify removal
        docker compose -f $file ls | Out-Null
        Write-Host "Service $service has been removed." -ForegroundColor Green    
    } else {
        Write-Host "Service $service is not running. Nothing to do." -ForegroundColor Gray
    }
}

function drun {
    # 1. Resolve Variables: Prioritize Override, fallback to Default
    $file    = if ($Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)  { $Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE }  else { $Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT }
    $service = if ($Env:DOCKER_SHELL_SERVICE_OVERRIDE)       { $Env:DOCKER_SHELL_SERVICE_OVERRIDE }       else { $Env:DOCKER_SHELL_SERVICE_DEFAULT }
    $workdir = if ($Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE)     { $Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE }     else { $Env:DOCKER_SANDBOX_WORKDIR_DEFAULT }
    $root    = if ($Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)   { $Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE }   else { $Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT }

    # 2. Validation
    if ([string]::IsNullOrWhiteSpace($file) -or -not (Test-Path $file)) {
        Write-Error "Invalid or missing Compose File: $file"
        return
    }

    # Write-Host "Config: Service [$service] via [$file]" -ForegroundColor Cyan

    # 3. Ensure Service is Running
    $checkRunning = { 
        docker compose -f $file ps --filter "status=running" --format "{{.Service}}" | Select-String -Pattern "^$($service)$" 
    }

    if (-not (& $checkRunning)) {
        # Write-Host "Starting $service..." -ForegroundColor Yellow
        
        # Inject paths into the environment for Compose interpolation
        $Env:DOCKER_SANDBOX_HOST_ROOT = $root
        $Env:DOCKER_SANDBOX_WORKDIR   = $workdir

        docker compose -f $file up -d --quiet-pull --remove-orphans --no-recreate $service *>$null
        
        if (-not (& $checkRunning)) {
            Write-Error "Failed to start service $service."
            return
        }
    }

    # Write-Host "Service $service is Ready." -ForegroundColor Green

    # 4. Execute
    if ($args.Count -eq 0) {
        # Interactive entry
        docker compose -f $file exec $service /usr/local/bin/entrypoint.sh
    } else {
        # Non-interactive command string via Base64 to preserve shell characters
        $cmdB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($args -join ' ')))
        docker compose -f $file exec $service bash -c "source /etc/bash.bashrc 2>/dev/null; echo $cmdB64 | base64 -d | bash"
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

export DOCKER_SHELL_COMPOSE_FILE_DEFAULT="/mnt/c/Users/$USER/dev/shell-mcp-server/docker/docker-compose.yml"
export DOCKER_SHELL_SERVICE_DEFAULT="drun" 

export DOCKER_SANDBOX_HOST_ROOT_DEFAULT="/mnt/c/Users/$USER/dev/repo"
export DOCKER_SANDBOX_WORKDIR_DEFAULT="/mnt/c/Users/$USER/dev/repo"

drun_rm(){
    # 1. Simplify variable assignment with defaults (${VAR:-DEFAULT})
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
    # 1. Simplify variable assignment with defaults (${VAR:-DEFAULT})
    export DOCKER_SHELL_COMPOSE_FILE="${DOCKER_SHELL_COMPOSE_FILE_OVERRIDE:-$DOCKER_SHELL_COMPOSE_FILE_DEFAULT}"
    export DOCKER_SHELL_SERVICE="${DOCKER_SHELL_SERVICE_OVERRIDE:-$DOCKER_SHELL_SERVICE_DEFAULT}"
    export DOCKER_SANDBOX_HOST_ROOT="${DOCKER_SANDBOX_HOST_ROOT_OVERRIDE:-$DOCKER_SANDBOX_HOST_ROOT_DEFAULT}"
    export DOCKER_SANDBOX_WORKDIR="${DOCKER_SANDBOX_WORKDIR_OVERRIDE:-$DOCKER_SANDBOX_WORKDIR_DEFAULT}"

    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi
    
    # 2. Check if the service is running (Improved logic)
    # We check the exit code of grep directly in the if statement
    if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
        echo "Service $DOCKER_SHELL_SERVICE not running. Starting..."
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" up -d --quiet-pull --no-recreate --remove-orphans "$DOCKER_SHELL_SERVICE" > /dev/null 2>&1
        
        # Verify it actually started
        if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
            echo "Error: Service $DOCKER_SHELL_SERVICE failed to start. Exit." >&2
            return 1
        fi
    fi

    # echo "Service $DOCKER_SHELL_SERVICE is running. Ready"

    # 3. Exec into the container
    if [ $# -eq 0 ]; then
        # Interactive entry
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" /usr/local/bin/entrypoint.sh
    else
        # Use "$*" to preserve spaces in the command string
        local cmd="$*"
        # Execute via bash -c
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" bash -c "source /etc/bash.bashrc 2>/dev/null; $cmd"
    fi
}


# This fails because drun is a Bash function, and functions are not automatically exported to subshells, even when you source ~/.bashrc.
export -f drun
export -f drun_rm

```
