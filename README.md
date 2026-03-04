# docker compose for safe shell execution


### build

```powershell

docker compose build

```

### run


```powershell

docker compose run --rm app bash -c "ls \&\& echo hello >> log.txt"

docker compose run --rm app bash -ic "mkdir -p test \&\& touch package.json \&\& cd test \&\& npm i"



docker compose run --rm -q --remove-orphans app bash  -ic "mkdir -p test \&\& touch package.json \&\& cd test \&\& npm i"

```

### Use on Windows


- create powershell profile

```powershell
notepad $PROFILE

```

- add 'drun' to profile

```

$Env:DOCKER\_SHELL\_CONFIG = "C:\\Users\\axdev\\programs\\docker\\docker-compose.yml"

$Env:DOCKER\_SHELL\_SERVICE = "drun"

function drun {


    if ($Env:DOCKER\_SHELL\_CONFIG) {
        # Use -f to point to the correct compose file location
        docker compose -f "$Env:DOCKER\_SHELL\_CONFIG" run --rm -q --remove-orphans --remove-orphans $Env:DOCKER\_SHELL\_SERVICE bash -ic "$args"
    } else {
        Write-Error "Could not find docker-compose.yml in this or any parent directory."
    }
}

```


- use drun

```

drun "uname -a"

```