$profileContent = @'

# Docker Shell Configuration
$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT = "$HOME\dev\shell-mcp-server\docker\docker-compose.yml"
$Env:DOCKER_SHELL_SERVICE_DEFAULT = "drun"
$ENV:DOCKER_SANDBOX_WORKDIR_DEFAULT = "/app/dev/repo"
$ENV:DOCKER_SANDBOX_HOST_ROOT_DEFAULT = "$HOME\dev\repo"


function drun_rm {
    `$file    = if (`$Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)  { `$Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE }  else { `$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT }
    `$service = if (`$Env:DOCKER_SHELL_SERVICE_OVERRIDE)       { `$Env:DOCKER_SHELL_SERVICE_OVERRIDE }       else { `$Env:DOCKER_SHELL_SERVICE_DEFAULT }
    `$workdir = if (`$Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE)     { `$Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE }     else { `$Env:DOCKER_SANDBOX_WORKDIR_DEFAULT }
    `$root    = if (`$Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)   { `$Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE }   else { `$Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT }

    Write-Host "--- Configuration ---" -ForegroundColor Cyan
    Write-Host "COMPOSE_FILE: `$file"
    Write-Host "SERVICE:      `$service"
    Write-Host "WORKDIR:      `$workdir"
    Write-Host "HOST_ROOT:    `$root"

    if ([string]::IsNullOrWhiteSpace(`$file) -or -not (Test-Path `$file)) {
        Write-Error "Invalid or missing Compose File: `$file"
        return
    }

    `$isRunning = docker compose -f `$file ps --filter "status=running" --format "{{.Service}}" | 
                 Select-String -Pattern "^`$(`$service)`$"

    if (`$isRunning) {
        Write-Host "Cleaning up service `$service..." -ForegroundColor Yellow
        docker compose -f `$file down --volumes --remove-orphans | Out-Null
        docker compose -f `$file ls | Out-Null
        Write-Host "Service `$service has been removed." -ForegroundColor Green    
    } else {
        Write-Host "Service `$service is not running. Nothing to do." -ForegroundColor Gray
    }
}

function drun {
    `$file    = if (`$Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE)  { `$Env:DOCKER_SHELL_COMPOSE_FILE_OVERRIDE }  else { `$Env:DOCKER_SHELL_COMPOSE_FILE_DEFAULT }
    `$service = if (`$Env:DOCKER_SHELL_SERVICE_OVERRIDE)       { `$Env:DOCKER_SHELL_SERVICE_OVERRIDE }       else { `$Env:DOCKER_SHELL_SERVICE_DEFAULT }
    `$workdir = if (`$Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE)     { `$Env:DOCKER_SANDBOX_WORKDIR_OVERRIDE }     else { `$Env:DOCKER_SANDBOX_WORKDIR_DEFAULT }
    `$root    = if (`$Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE)   { `$Env:DOCKER_SANDBOX_HOST_ROOT_OVERRIDE }   else { `$Env:DOCKER_SANDBOX_HOST_ROOT_DEFAULT }

    if ([string]::IsNullOrWhiteSpace(`$file) -or -not (Test-Path `$file)) {
        Write-Error "Invalid or missing Compose File: `$file"
        return
    }

    `$checkRunning = { 
        docker compose -f `$file ps --filter "status=running" --format "{{.Service}}" | Select-String -Pattern "^`$(`$service)`$" 
    }

    if (-not (& `$checkRunning)) {
        `$Env:DOCKER_SANDBOX_HOST_ROOT = `$root
        `$Env:DOCKER_SANDBOX_WORKDIR   = `$workdir

        docker compose -f `$file up -d --quiet-pull --remove-orphans --no-recreate `$service *>`$null
        
        if (-not (& `$checkRunning)) {
            Write-Error "Failed to start service `$service."
            return
        }
    }

    if (`$args.Count -eq 0) {
        docker compose -f `$file exec `$service /usr/local/bin/entrypoint.sh
    } else {
        `$cmdB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((`$args -join ' ')))
        docker compose -f `$file exec `$service bash -c "source /etc/bash.bashrc 2>/dev/null; echo `$cmdB64 | base64 -d | bash"
    }
}
'@

$profilePath = if ($PROFILE) { $PROFILE } else { "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" }
$profileDir = Split-Path -Parent $profilePath

if ([string]::IsNullOrWhiteSpace($profileDir)) {
    $profileDir = "$HOME\Documents\PowerShell"
}

if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path $profilePath) {
    $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existingContent -match 'DOCKER_SHELL_COMPOSE_FILE_DEFAULT') {
        Write-Host "Docker Shell configuration already exists in profile." -ForegroundColor Yellow
        Write-Host "Please manually edit $profilePath to update." -ForegroundColor Yellow
        exit 0
    }
}

Add-Content -Path $profilePath -Value $profileContent
Write-Host "Docker Shell configuration added to $profilePath" -ForegroundColor Green
