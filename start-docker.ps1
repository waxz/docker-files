$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT = "$HOME\dev\shell-mcp-server\docker\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE_DEFAULT = "drun"

$Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT = "$HOME\dev\repo"
$Env:DOCKER_SANDBOX_WORKDIR_DEFAULT = "/app/dev/repo"


function Resolve-DrunEnv {

    $script:DOCKER_SHELL_COMPOSE_FILE = if ($Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE) { $Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE } else { $Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT }

    $script:SERVICE = if ($Env:DOCKER_SHELL_SERVICE_OVERRIDE) { $Env:DOCKER_SHELL_SERVICE_OVERRIDE } else { $Env:DOCKER_SHELL_SERVICE_DEFAULT }

    $script:DOCKER_SANDBOX_HOST_ROOT = if ($Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE) { $Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE } else { $Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT }

    $script:DOCKER_SANDBOX_WORKDIR = if ($Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE) { $Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE } else { $Env:DOCKER_SANDBOX_WORKDIR_DEFAULT }

    $script:COMPOSE_DIR = Split-Path $DOCKER_SHELL_COMPOSE_FILE -Parent
    $script:DOCKERFILE = Join-Path $COMPOSE_DIR "Dockerfile"

    $script:IMAGE = "$SERVICE-image"
    $script:CONTAINER = $SERVICE

}


function Test-ContainerRunning {

    docker ps --format "{{.Names}}" |
    Select-String -Pattern "^$CONTAINER$" -Quiet

}


function Test-ContainerExists {

    docker ps -a --format "{{.Names}}" |
    Select-String -Pattern "^$CONTAINER$" -Quiet

}


function Build-ImageIfNeeded {

    if (-not (Test-Path $DOCKERFILE)) {
        Write-Error "Dockerfile not found: $DOCKERFILE"
        return $false
    }

    $hashFile = Join-Path $COMPOSE_DIR ".dockerfile.hash"

    $newHash = (Get-FileHash $DOCKERFILE -Algorithm SHA256).Hash

    if ((-not (Test-Path $hashFile)) -or ((Get-Content $hashFile) -ne $newHash)) {

        Write-Host "Building image $IMAGE..." -ForegroundColor Yellow

        docker build --platform linux/amd64 -t $IMAGE $COMPOSE_DIR | Out-Null

        Set-Content $hashFile $newHash

    }

    return $true
}


function Start-DrunContainer {

    $root = $DOCKER_SANDBOX_HOST_ROOT -replace '\\','/'
    $root = $root -replace '^([A-Za-z]):','/$1'
    $root = $root.ToLower()


    docker run --platform linux/amd64 -d `
        --name $CONTAINER `
        -v "$root`:$DOCKER_SANDBOX_WORKDIR" `
        -w $DOCKER_SANDBOX_WORKDIR `
        --init `
        --network none `
        --cap-drop ALL `
        --security-opt no-new-privileges `
        $IMAGE `
        tail -f /dev/null | Out-Null

}


function drun_rm {

    Resolve-DrunEnv

    if (Test-ContainerExists) {

        docker rm -f $CONTAINER | Out-Null
        Write-Host "Container removed: $CONTAINER" -ForegroundColor Green

    }
    else {

        Write-Host "Container not found." -ForegroundColor Gray

    }

}


function drun {

    Resolve-DrunEnv

    if (-not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {

        Write-Error "Config not found: $DOCKER_SHELL_COMPOSE_FILE"
        return

    }

    if (-not (Build-ImageIfNeeded)) { return }

    if (-not (Test-ContainerRunning)) {

        if (Test-ContainerExists) {

            docker start $CONTAINER | Out-Null

        }
        else {

            Write-Host "Starting container $CONTAINER..." -ForegroundColor Yellow
            Start-DrunContainer

        }

    }

    if ($args.Count -eq 0) {

        docker exec -t $CONTAINER /entrypoint.sh

    }
    else {

        $cmd = $args -join " "
        $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
        $cmdB64 = [Convert]::ToBase64String($cmdBytes)

        docker exec -t $CONTAINER bash -c "source /etc/bash.bashrc 2>/dev/null; echo $cmdB64 | base64 -d | bash"

    }

}