$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT = "$HOME\dev\shell-mcp-server\docker\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE_DEFAULT = "drun"
$Env:DOCKER_SANDBOX_WORKDIR_DEFAULT = "/app/dev/repo"
$Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT = "$HOME\dev\repo"


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