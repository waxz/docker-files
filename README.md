# docker compose for safe shell execution


### build

```powershell

docker compose build

```

### run


```powershell

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

$Env:DOCKER_SHELL_CONFIG = "$HOME\programs\docker\docker-compose.yml"

$Env:DOCKER_SHELL_SERVICE = "drun"

function drun {
    if (Test-Path $Env:DOCKER_SHELL_CONFIG) {
        # 1. Ensure the container is running; redirect all output to null to hide logs
        docker compose -f "$Env:DOCKER_SHELL_CONFIG" up --quiet-pull --remove-orphans -d $Env:DOCKER_SHELL_SERVICE > $null 2>&1

        # 2. Exec into the persistent container
       

        if ($args.Count -eq 0) {
            docker compose -f "$Env:DOCKER_SHELL_CONFIG" exec $Env:DOCKER_SHELL_SERVICE /usr/local/bin/entrypoint.sh
        } else {
            # Joining args ensures multi-word commands are passed correctly to bash
            #$cmd = $args -join " "
            $cmd = $args -join ' '
            docker compose -f "$Env:DOCKER_SHELL_CONFIG" exec $Env:DOCKER_SHELL_SERVICE bash -c "$args"
        }
    } else {
        Write-Error "Could not find config at: $Env:DOCKER_SHELL_CONFIG"
    }
}

```


- use drun

```powershell
drun "uname -a"

```