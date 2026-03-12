# ---------- defaults ----------

export DOCKER_SHELL_COMPOSE_FILE_DEFAULT="/mnt/c/Users/$USER/dev/shell-mcp-server/docker/docker-compose.yml"
export DOCKER_SHELL_SERVICE_DEFAULT="drun"

export DOCKER_SANDBOX_HOST_ROOT_DEFAULT="/mnt/c/Users/$USER/dev/repo"
export DOCKER_SANDBOX_WORKDIR_DEFAULT="/app/dev/repo"


# ---------- helpers ----------

_drun_resolve_env() {

export DOCKER_SHELL_COMPOSE_FILE="${DOCKER_SHELL_COMPOSE_FILE_OVERRIDE:-$DOCKER_SHELL_COMPOSE_FILE_DEFAULT}"
export DOCKER_SHELL_SERVICE="${DOCKER_SHELL_SERVICE_OVERRIDE:-$DOCKER_SHELL_SERVICE_DEFAULT}"
export DOCKER_SANDBOX_HOST_ROOT="${DOCKER_SANDBOX_HOST_ROOT_OVERRIDE:-$DOCKER_SANDBOX_HOST_ROOT_DEFAULT}"
export DOCKER_SANDBOX_WORKDIR="${DOCKER_SANDBOX_WORKDIR_OVERRIDE:-$DOCKER_SANDBOX_WORKDIR_DEFAULT}"

SERVICE="$DOCKER_SHELL_SERVICE"

COMPOSE_DIR="$(dirname "$DOCKER_SHELL_COMPOSE_FILE")"
DOCKERFILE="$COMPOSE_DIR/Dockerfile"

IMAGE="${SERVICE}-image"
CONTAINER="$SERVICE"

}


_container_running() {
docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"
}


_container_exists() {
docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"
}


_build_if_needed() {

if [ ! -f "$DOCKERFILE" ]; then
    echo "Dockerfile missing: $DOCKERFILE" >&2
    return 1
fi

HASH_FILE="$COMPOSE_DIR/.dockerfile.hash"
NEW_HASH="$(sha256sum "$DOCKERFILE" | awk '{print $1}')"

if [ ! -f "$HASH_FILE" ] || [ "$NEW_HASH" != "$(cat "$HASH_FILE")" ]; then

    echo "Building docker image $IMAGE"

    docker build -t "$IMAGE" "$COMPOSE_DIR" || return 1

    echo "$NEW_HASH" > "$HASH_FILE"

fi

}


_start_container() {

docker run -d \
--name "$CONTAINER" \
-v "$DOCKER_SANDBOX_HOST_ROOT:$DOCKER_SANDBOX_WORKDIR" \
-w "$DOCKER_SANDBOX_WORKDIR" \
--init \
--network none \
--cap-drop ALL \
--security-opt no-new-privileges \
"$IMAGE" \
tail -f /dev/null

}


# ---------- main commands ----------


drun_rm() {

_drun_resolve_env

if _container_exists; then

    docker rm -f "$CONTAINER" >/dev/null
    echo "Container removed: $CONTAINER"

else

    echo "Container not found"

fi

}



drun() {

_drun_resolve_env

if [ ! -f "$DOCKER_SHELL_COMPOSE_FILE" ]; then
    echo "Config not found: $DOCKER_SHELL_COMPOSE_FILE" >&2
    return 1
fi

_build_if_needed || return 1

if ! _container_running; then

    if _container_exists; then
        docker start "$CONTAINER" >/dev/null
    else
        _start_container || return 1
    fi

fi


if [ $# -eq 0 ]; then

    docker exec -t "$CONTAINER" /entrypoint.sh

else

    CMD_B64="$(printf "%s" "$*" | base64 -w0)"

    docker exec -t "$CONTAINER" bash -c \
    "source /etc/bash.bashrc 2>/dev/null; echo $CMD_B64 | base64 -d | bash"

fi

}


export -f drun
export -f drun_rm