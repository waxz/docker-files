



\### create Dockerfile



```



```



\### create docker-compose.yml



```

```



\### build



```

docker compose build

```



\#### run

```bash

docker compose run --rm app bash -c "ls \&\& echo hello >> log.txt"

docker compose run --rm app bash -ic "mkdir -p test \&\& touch package.json \&\& cd test \&\& npm i"



docker compose run --rm -q --remove-orphans app bash  -ic "mkdir -p test \&\& touch package.json \&\& cd test \&\& npm i"



```





\### Windows



create powershell profile

```

notepad $PROFILE

```

add 'drun' to profile



```

$Env:DOCKER\_SHELL\_CONFIG = "C:\\Users\\axdev\\programs\\docker\\docker-compose.yml"

$Env:DOCKER\_SHELL\_SERVICE = "drun"

function drun {





&nbsp;   if ($Env:DOCKER\_SHELL\_CONFIG) {

&nbsp;       # Use -f to point to the correct compose file location

&nbsp;       docker compose -f "$Env:DOCKER\_SHELL\_CONFIG" run --rm -q --remove-orphans --remove-orphans $Env:DOCKER\_SHELL\_SERVICE bash -ic "$args"

&nbsp;   } else {

&nbsp;       Write-Error "Could not find docker-compose.yml in this or any parent directory."

&nbsp;   }

}

```



```

drun "uname -a"

```





