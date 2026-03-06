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



function drun_rm{


    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)) { 
    }else{
        $DOCKER_SHELL_COMPOSE_FILE = "$ENV:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SHELL_SERVICE_OVERRIDE)) { 
    }else{
        $DOCKER_SHELL_SERVICE = "$ENV:DOCKER_SHELL_SERVICE_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SANDBOX_WORKDIR_OVERRIDE)) { 
    }else{
        $DOCKER_SANDBOX_WORKDIR = "$ENV:DOCKER_SANDBOX_WORKDIR_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)) { 
    }else{
        $DOCKER_SANDBOX_HOST_ROOT = "$ENV:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE"
    }


    Write-Host "DOCKER_SHELL_COMPOSE_FILE = $DOCKER_SHELL_COMPOSE_FILE" -ForegroundColor Cyan
    Write-Host "DOCKER_SHELL_SERVICE = $DOCKER_SHELL_SERVICE" -ForegroundColor Cyan
    Write-Host "DOCKER_SANDBOX_WORKDIR = $DOCKER_SANDBOX_WORKDIR" -ForegroundColor Cyan
    Write-Host "DOCKER_SANDBOX_HOST_ROOT = $DOCKER_SANDBOX_HOST_ROOT" -ForegroundColor Cyan



    if (-not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "Could not find config at: $DOCKER_SHELL_COMPOSE_FILE"
        return
    }

    # 1. Check if the specific service is already running
    $isRunning = docker compose -f $DOCKER_SHELL_COMPOSE_FILE ps --filter "status=running" --format "{{.Service}}" | 
                 Select-String -Pattern "^$($DOCKER_SHELL_SERVICE)$"


    if ( $isRunning) {
        Write-Host "Service $Env:DOCKER_SHELL_SERVICE is running." -ForegroundColor Cyan
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE  kill | Out-Null
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE rm | Out-Null
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE ls | Out-Null
        Write-Host "Service $Env:DOCKER_SHELL_SERVICE is removed." -ForegroundColor Cyan    
    }
}


function drun {


    $DOCKER_SHELL_COMPOSE_FILE = "$ENV:DOCKER_SHELL_COMPOSE_FILE_DEFAULT"
    $DOCKER_SHELL_SERVICE = "$ENV:DOCKER_SHELL_SERVICE_DEFAULT"
    $DOCKER_SANDBOX_WORKDIR = "$ENV:DOCKER_SANDBOX_WORKDIR_DEFAULT"
    $DOCKER_SANDBOX_HOST_ROOT = "$ENV:DOCKER_SANDBOX_HOST_ROOT_DEFAULT"

    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)) { 
    }else{
        $DOCKER_SHELL_COMPOSE_FILE = "$ENV:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SHELL_SERVICE_OVERRIDE)) { 
    }else{
        $DOCKER_SHELL_SERVICE = "$ENV:DOCKER_SHELL_SERVICE_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SANDBOX_WORKDIR_OVERRIDE)) { 
    }else{
    $DOCKER_SANDBOX_WORKDIR = "$ENV:DOCKER_SANDBOX_WORKDIR_OVERRIDE"
    }
    if ([string]::IsNullOrWhiteSpace($ENV:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)) { 
    }else{
    $DOCKER_SANDBOX_HOST_ROOT = "$ENV:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE"
    }


    Write-Host "DOCKER_SHELL_COMPOSE_FILE = $DOCKER_SHELL_COMPOSE_FILE" -ForegroundColor Cyan
    Write-Host "DOCKER_SHELL_SERVICE = $DOCKER_SHELL_SERVICE" -ForegroundColor Cyan
    Write-Host "DOCKER_SANDBOX_WORKDIR = $DOCKER_SANDBOX_WORKDIR" -ForegroundColor Cyan
    Write-Host "DOCKER_SANDBOX_HOST_ROOT = $DOCKER_SANDBOX_HOST_ROOT" -ForegroundColor Cyan




    if (-not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "Could not find config at: $DOCKER_SHELL_COMPOSE_FILE"
        return
    }

    # 1. Check if the specific service is already running
    $isRunning = docker compose -f $DOCKER_SHELL_COMPOSE_FILE ps --filter "status=running" --format "{{.Service}}" | 
                 Select-String -Pattern "^$($DOCKER_SHELL_SERVICE)$"


    if (-not $isRunning) {
        Write-Host "Service $DOCKER_SHELL_COMPOSE_FILE , $DOCKER_SHELL_SERVICE not running. Starting..." -ForegroundColor Cyan

        $ENV:DOCKER_SANDBOX_HOST_ROOT = $DOCKER_SANDBOX_HOST_ROOT
        $ENV:DOCKER_SANDBOX_WORKDIR = $DOCKER_SANDBOX_WORKDIR

        # Note: --env requires NAME=VALUE format
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE `
            run --env DOCKER_SANDBOX_HOST_ROOT=$DOCKER_SANDBOX_HOST_ROOT `
            --env DOCKER_SANDBOX_WORKDIR=$DOCKER_SANDBOX_WORKDIR `
            --entrypoint "/usr/local/bin/entrypoint.sh" -d --remove-orphans $DOCKER_SHELL_SERVICE
    }
    $isRunning = docker compose -f $DOCKER_SHELL_COMPOSE_FILE ps --filter "status=running" --format "{{.Service}}" | 
                 Select-String -Pattern "^$($DOCKER_SHELL_SERVICE)$"
    if ( $isRunning) {
        Write-Host "Service $DOCKER_SHELL_SERVICE is running. Starting..." -ForegroundColor Cyan
         
    }else{
        Write-Error "Service $DOCKER_SHELL_SERVICE is not running. Starting..." -ForegroundColor Cyan
        return
    }


    # 2. Execute command or enter shell
    if ($args.Count -eq 0) {
        # Interactive entry
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE `
            exec $Env:DOCKER_SHELL_SERVICE /usr/local/bin/entrypoint.sh
    } else {
        # Non-interactive command string
        $cmd = $args -join ' '
        $cmdB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cmd))
        
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE `
            exec $DOCKER_SHELL_SERVICE bash -c "source /etc/bash.bashrc 2>/dev/null; echo $cmdB64 | base64 -d | bash"
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
    if [ -z "$DOCKER_SHELL_COMPOSE_FILE_OVERRIDE" ] ; then
        export DOCKER_SHELL_COMPOSE_FILE="$DOCKER_SHELL_COMPOSE_FILE_DEFAULT"
    else
        export DOCKER_SHELL_COMPOSE_FILE="$DOCKER_SHELL_COMPOSE_FILE_OVERRIDE"
    fi

    if [ -z "$DOCKER_SHELL_SERVICE_OVERRIDE" ] ; then
        export DOCKER_SHELL_SERVICE="$DOCKER_SHELL_SERVICE_DEFAULT"
    else
        export DOCKER_SHELL_SERVICE="$DOCKER_SHELL_SERVICE_OVERRIDE"
    fi

    if [ -z "$DOCKER_SANDBOX_HOST_ROOT_OVERRIDE" ] ; then
        export DOCKER_SANDBOX_HOST_ROOT="$DOCKER_SANDBOX_HOST_ROOT_DEFAULT"
    else
        export DOCKER_SANDBOX_HOST_ROOT="$DOCKER_SANDBOX_HOST_ROOT_OVERRIDE"
    fi

    if [ -z "$DOCKER_SANDBOX_WORKDIR_OVERRIDE" ] ; then
        export DOCKER_SANDBOX_WORKDIR="$DOCKER_SANDBOX_WORKDIR_DEFAULT"
    else
        export DOCKER_SANDBOX_WORKDIR="$DOCKER_SANDBOX_WORKDIR_OVERRIDE"
    fi

    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi
    docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" kill "$DOCKER_SHELL_SERVICE"
    docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" rm "$DOCKER_SHELL_SERVICE"
    return 0
}
drun() {
    if [ -z "$DOCKER_SHELL_COMPOSE_FILE_OVERRIDE" ] ; then
        export DOCKER_SHELL_COMPOSE_FILE="$DOCKER_SHELL_COMPOSE_FILE_DEFAULT"
    else
        export DOCKER_SHELL_COMPOSE_FILE="$DOCKER_SHELL_COMPOSE_FILE_OVERRIDE"
    fi

    if [ -z "$DOCKER_SHELL_SERVICE_OVERRIDE" ] ; then
        export DOCKER_SHELL_SERVICE="$DOCKER_SHELL_SERVICE_DEFAULT"
    else
        export DOCKER_SHELL_SERVICE="$DOCKER_SHELL_SERVICE_OVERRIDE"
    fi

    if [ -z "$DOCKER_SANDBOX_HOST_ROOT_OVERRIDE" ] ; then
        export DOCKER_SANDBOX_HOST_ROOT="$DOCKER_SANDBOX_HOST_ROOT_DEFAULT"
    else
        export DOCKER_SANDBOX_HOST_ROOT="$DOCKER_SANDBOX_HOST_ROOT_OVERRIDE"
    fi

    if [ -z "$DOCKER_SANDBOX_WORKDIR_OVERRIDE" ] ; then
        export DOCKER_SANDBOX_WORKDIR="$DOCKER_SANDBOX_WORKDIR_DEFAULT"
    else
        export DOCKER_SANDBOX_WORKDIR="$DOCKER_SANDBOX_WORKDIR_OVERRIDE"
    fi

    if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
        echo "Error: Could not find config at $DOCKER_SHELL_COMPOSE_FILE" >&2
        return 1
    fi
    
    # 1. Check if the service is already running
    # -q returns 0 if found, 1 if not
    if ! docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" ps --filter "status=running" --format "{{.Service}}" | grep -q "^${DOCKER_SHELL_SERVICE}$"; then
        echo "Service $DOCKER_SHELL_SERVICE not running. Starting..."
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" up -d --quiet-pull --no-recreate "$DOCKER_SHELL_SERVICE" > /dev/null 2>&1
    fi

    # 2. Exec into the container
    if [ $# -eq 0 ]; then
        # Interactive entry (uses the tmux entrypoint)
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" /usr/local/bin/entrypoint.sh
    else
        # Join arguments into a single command string
        local cmd="$*"
        # Source bashrc to ensure uv/pip/aliases are loaded for the command
        docker compose -f "$DOCKER_SHELL_COMPOSE_FILE" exec "$DOCKER_SHELL_SERVICE" bash -c "source /etc/bash.bashrc 2>/dev/null; $cmd"
    fi
}

# This fails because drun is a Bash function, and functions are not automatically exported to subshells, even when you source ~/.bashrc.
export -f drun
export -f drun_rm

```
