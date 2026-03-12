$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT = "$HOME\dev\shell-mcp-server\docker\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE_DEFAULT = "drun"
$Env:DOCKER_SANDBOX_WORKDIR_DEFAULT = "/app/dev/repo"
$Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT = "$HOME\dev\repo"




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

function Test-ServiceRunning {
    # 1. Use the script scope to ensure variables are seen
    if (-not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "DOCKER_SHELL_COMPOSE_FILE not found: $DOCKER_SHELL_COMPOSE_FILE"
        return $false
    }

    # 2. Capture the output and cast to [bool]
    # If the string is empty (service not running), it returns False
    # If the string contains the service name, it returns True

    #$result = (docker compose -f $DOCKER_SHELL_COMPOSE_FILE ps)
    #Write-Host " "
    #Write-Host "$result"


    $running = [bool](docker compose -f $DOCKER_SHELL_COMPOSE_FILE ps --filter "status=running" --format "{{.Service}}" | Select-String -Pattern "^$SERVICE$" ) 
    #Write-Host " "
   
    #Write-Host "running $running"
    
    return $running
}


function Build-ImageIfNeeded {

    if (-not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "DOCKER_SHELL_COMPOSE_FILE not found: $DOCKER_SHELL_COMPOSE_FILE"
        # return $false
    }

    $hashFile = Join-Path $COMPOSE_DIR ".dockerfile.hash"
    $entryFile = Join-Path $COMPOSE_DIR "entrypoint.sh"


    $newHash = (Get-FileHash $entryFile -Algorithm SHA256).Hash +(Get-FileHash $DOCKERFILE -Algorithm SHA256).Hash + (Get-FileHash $DOCKER_SHELL_COMPOSE_FILE -Algorithm SHA256).Hash

    if ((-not (Test-Path $hashFile)) -or ((Get-Content $hashFile) -ne $newHash)) {

        Write-Host "Building image $IMAGE..." -ForegroundColor Yellow

        docker compose -f $DOCKER_SHELL_COMPOSE_FILE build | Out-Null

        Set-Content $hashFile $newHash

    }

    # return $true
}

function Check-Compose-File-Exist{
    if ([string]::IsNullOrWhiteSpace($DOCKER_SHELL_COMPOSE_FILE) -or -not (Test-Path $DOCKER_SHELL_COMPOSE_FILE)) {
        Write-Error "Invalid or missing Compose File: $DOCKER_SHELL_COMPOSE_FILE"
        return $false
    }
    return $true
}


function drun_rm {
    Resolve-DrunEnv
    # 2. Print Configuration
    Write-Host "--- Configuration ---" -ForegroundColor Cyan
    Write-Host "COMPOSE_FILE: $DOCKER_SHELL_COMPOSE_FILE"
    Write-Host "SERVICE:      $SERVICE"

    # 3. Validation
    
    if ( -not (Check-Compose-File-Exist)){
        return 
    }
    
    # 4. Check status and Cleanup
    $running = ( Test-ServiceRunning )

    # Write-Host "Cleaning up SERVICE $SERVICE , running: $running" -ForegroundColor Yellow

    if ( $running ) {
        Write-Host "Cleaning up SERVICE $SERVICE..." -ForegroundColor Yellow
        
        # Combined down command is cleaner than kill + rm
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE down | Out-Null
        
        # Verify removal
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE ls | Out-Null
        Write-Host "Service $SERVICE has been removed." -ForegroundColor Green    
    } else {
        Write-Host "Service $SERVICE is not running. Nothing to do." -ForegroundColor Gray
    }
    # Build-ImageIfNeeded
}

function drun {
    # 1. Resolve Variables: Prioritize Override, fallback to Default
    Resolve-DrunEnv
    # 2. Print Configuration
    # Write-Host "--- Configuration ---" -ForegroundColor Cyan
    # Write-Host "COMPOSE_FILE:                $DOCKER_SHELL_COMPOSE_FILE"
    # Write-Host "SERVICE:                     $SERVICE"
    # Write-Host "DOCKER_SANDBOX_HOST_ROOT:    $DOCKER_SANDBOX_HOST_ROOT"
    # Write-Host "DOCKER_SANDBOX_WORKDIR:      $DOCKER_SANDBOX_WORKDIR"



    # 2. Validation
    if ( -not (Check-Compose-File-Exist)){
        return 
    }

    # Write-Host "Config: Service [$SERVICE] in [$DOCKER_SHELL_COMPOSE_FILE]" -ForegroundColor Cyan


    # 3. Ensure Service is Running
    $running = ( Test-ServiceRunning )
    
    if (-not $running  ){
        # Write-Host "Starting $SERVICE in [$DOCKER_SHELL_COMPOSE_FILE] ..." -ForegroundColor Yellow
        
        # Inject paths into the environment for Compose interpolation
        $Env:DOCKER_SANDBOX_HOST_ROOT = $DOCKER_SANDBOX_HOST_ROOT
        $Env:DOCKER_SANDBOX_WORKDIR   = $DOCKER_SANDBOX_WORKDIR

        Build-ImageIfNeeded

        docker compose -f $DOCKER_SHELL_COMPOSE_FILE up -d  --quiet-pull --quiet-build --remove-orphans --no-recreate $SERVICE  *> $null
        $running = ( Test-ServiceRunning )

        if (-not $running ) {
            Write-Error "Failed to start SERVICE $SERVICE."
            return
        }
    }

    # Write-Host "Service $SERVICE is Ready." -ForegroundColor Green

    # 4. Execute
    if ($args.Count -eq 0) {
        # Interactive entry
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE exec $SERVICE /entrypoint.sh
    } else {
        # Non-interactive command string via Base64 to preserve shell characters
        $cmdB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($args -join ' ')))
        docker compose -f $DOCKER_SHELL_COMPOSE_FILE exec $SERVICE bash -c "source /etc/bash.bashrc 2>/dev/null; echo $cmdB64 | base64 -d | bash"
    }
}