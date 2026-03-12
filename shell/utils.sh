#!/usr/bin/env bash
# set -euo pipefail

# https://stackoverflow.com/questions/3236871/how-to-return-a-string-value-from-a-bash-function
# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script

# Source - https://stackoverflow.com/a/246128
# Posted by dogbane, modified by community. See post 'Timeline' for change history
# Retrieved 2026-03-12, License - CC BY-SA 4.0

#!/usr/bin/env bash

get_script_dir()
{
    local SOURCE_PATH="${BASH_SOURCE[0]}"
    local SYMLINK_DIR
    local SCRIPT_DIR
    # Resolve symlinks recursively
    while [ -L "$SOURCE_PATH" ]; do
        # Get symlink directory
        SYMLINK_DIR="$( cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd )"
        # Resolve symlink target (relative or absolute)
        SOURCE_PATH="$(readlink "$SOURCE_PATH")"
        # Check if candidate path is relative or absolute
        if [[ $SOURCE_PATH != /* ]]; then
            # Candidate path is relative, resolve to full path
            SOURCE_PATH=$SYMLINK_DIR/$SOURCE_PATH
        fi
    done
    # Get final script directory path from fully resolved source path
    SCRIPT_DIR="$(cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd)"
    echo "$SCRIPT_DIR"
}

DIR=$(get_script_dir)

export PATH="$DIR:$PATH"


gh_install() {

  if [[ $# -ne 3 ]]; then
    echo "Please set repo, arch, and filename"
    return 1
  fi

  local repo="$1"
  local arch="$2"
  local filename="$3"

  echo "Set repo: $repo, arch: $arch, filename: $filename"

  local url=""
  local count=0

  while [[ -z "$url" && "$count" -lt 5 ]]; do
    content=$(curl -s -L -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$repo/releases")

    # 1. Get the list of all matching URLs as an array
    all_matches=$(echo "$content" | jq -r --arg arch "$arch" '.[0].assets[] | select(.name | endswith($arch)) | .browser_download_url')

    # 2. Count how many matches were found
    if [[ -z "$all_matches" ]]; then
        match_count=0
    else
        match_count=$(echo "$all_matches" | grep -c '^http' || echo 0)
    
    fi

    if [[ "$match_count" -gt 1 ]]; then
      echo "Error: Multiple assets match '$arch'. Please be more specific."
      echo "Matches found:"
      echo "$all_matches"
      return 1
    elif [[ "$match_count" -eq 1 ]]; then
      url="$all_matches"
      break;
    else
      # No matches, loop continues to retry...
      echo "No match found for '$arch' (Attempt $((count + 1))/5)"
      count=$((count + 1))
      sleep 1
    fi

  done

  if [[ -z "$url" ]]; then
    echo "Failed to find a valid download URL after $count attempts."
    return 1
  fi

  echo "Download URL: $url"
  echo "Download filename: $filename"
  curl -L "$url" -o "$filename" && echo "Downloaded $filename successfully." || echo "Failed to download $filename."
}

# Utility functions for managing processes
ps_kill() {

  if [[ $# -ne 1 ]]; then
    echo "Please set program"
    return 1
  fi
  program="$1"

  ps -A -o tid,cmd  | grep -v grep | grep "$program" | awk '{print $1}' | xargs -I {} /bin/bash -c ' sudo kill -9  {} '
}

kill_program(){

  if [[ $# -ne 1 ]]; then
    echo "Please set program"
    return 1
  fi
  program="$1"

  # Prefer pgrep when available; otherwise fall back to ps+grep.
  if command -v pgrep >/dev/null 2>&1; then
    EXISTING_PIDS=$(pgrep -f "$program" || true)
  else
    # Use ps to list processes, then filter. Use grep -F to match literal string.
    EXISTING_PIDS=$(ps -eo pid,cmd --no-headers | grep -v grep | grep -F -- "$program" | awk '{print $1}' || true)
  fi

  if [ -n "$EXISTING_PIDS" ]; then
    echo "Killing existing $program processes: $EXISTING_PIDS"
    kill -9 $EXISTING_PIDS || true
    sleep 1
  fi

}

histclean() {
  history | awk '{$1=""; print substr($0,2)}'
}


extract_var() {
    if [[ $# -ne 2 ]]; then
    echo "Please var-file var-name"
    return 1
  fi

    local BASHRC="$1"
    local var="$2"
    local raw

    raw=$(grep -E "^export ${var}=|^${var}=" "$BASHRC" \
        | head -n1 \
        | sed -E "s/^(export +)?${var}=//")

    # Trim leading/trailing spaces
    raw=$(echo "$raw" | sed -E 's/^[ \t]+|[ \t]+$//g')

    # Remove ONE matching pair of quotes if present
    raw=$(echo "$raw" | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')

    # ALSO remove any dangling quotes like: abc" or "abc
    raw=$(echo "$raw" | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')

    echo "$raw"
}


extract_all_env() {
    grep -E '^(export +)?[A-Za-z_][A-Za-z0-9_]*=' "$VARFILE" \
    | sed -E 's/#.*$//' \
    | sed -E 's/^[ \t]+|[ \t]+$//g' \
    | while IFS= read -r line; do

        # Remove "export "
        line=$(echo "$line" | sed -E 's/^export +//')

        key="${line%%=*}"
        val="${line#*=}"

        # Strip surrounding quotes
        val=$(echo "$val" | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')
        val=$(echo "$val" | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')

        printf "%s=%s\n" "$key" "$val"
    done
}

# Start a daemon with PID tracking
start_daemon() {
    local name="$1"
    local pid_file="$2"
    local log_file="$3"
    shift 3
    local cmd="$@"
    
    rm -f "$pid_file"
    
    nohup setsid bash -c '
        echo $$ > "'"$pid_file"'"
        exec '"$cmd"'
    ' > "$log_file" 2>&1 &
    
    sleep 2
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✅ $name started (PID: $(cat "$pid_file"))"
        return 0
    else
        echo "❌ $name failed to start"
        return 1
    fi
}

# Stop a daemon by PID file
stop_daemon() {
    local name="$1"
    local pid_file="$2"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$pid_file"
        echo "✅ $name stopped (PID: $pid)"
    fi
}

# Kill process and free port
# Usage: free_port <port> [process_pattern] [max_wait]
# Example: free_port 10000 "v2ray run" 20
free_port() {
    local port="$1"
    local process_pattern="${2:-}"
    local max_wait="${3:-20}"
    
    echo "=== Clearing port $port ==="
    
    # Install fuser if missing
    if ! command -v fuser &> /dev/null; then
        apt-get update && apt-get install -y psmisc
    fi
    
    # Step 1: Kill by process name if provided
    if [ -n "$process_pattern" ]; then
        echo "Killing processes matching: $process_pattern"
        pkill -9 -f "$process_pattern" || true
        sleep 1
    fi
    
    # Step 2: Kill anything on the port
    echo "Killing anything on port $port..."
    fuser -k -9 "$port/tcp" 2>/dev/null || true
    sleep 1
    
    # Step 3: Wait for port to be free
    echo "Waiting for port $port to be free..."
    local count=0
    while ss -tlnp | grep -q ":$port "; do
        sleep 1
        ((count++))
        
        if [ $count -ge $max_wait ]; then
            echo "❌ Port $port still in use after ${max_wait}s"
            ss -tlnp | grep ":$port " || true
            return 1
        fi
        
        # Retry kill every 5 seconds
        if [ $((count % 5)) -eq 0 ]; then
            echo "Retrying kill..."
            [ -n "$process_pattern" ] && pkill -9 -f "$process_pattern" || true
            fuser -k -9 "$port/tcp" 2>/dev/null || true
        fi
    done
    
    echo "✅ Port $port is free."
    return 0
}

PID_TRACKER="/tmp/.nohup_pids"

nohup_run() {
  local logfile=$(realpath "$1")
  shift
  mkdir -p "$(dirname "$logfile")"

  # Use a subshell with 'exec' to ensure $! is the ACTUAL command's PID
  ( exec nohup env "$@" > "$logfile" 2>&1 < /dev/null ) &
  
  local pid=$!
  echo "$logfile:$pid" >> "$PID_TRACKER"
  echo "[$(date +'%H:%M:%S')] Started: [$*] (PID: $pid)"
}

nohup_stop() {
  local logfile=$(realpath "$1")
  local pid=$(grep "^$logfile:" "$PID_TRACKER" | tail -n 1 | cut -d: -f2)

  if [[ -n "$pid" ]]; then
    # Try SIGTERM first
    kill "$pid" 2>/dev/null
    
    # Wait a moment and force kill if it's a "zombie" or stubborn
    sleep 0.5
    if kill -0 "$pid" 2>/dev/null; then
       echo "PID $pid still alive, forcing kill..."
       kill -9 "$pid" 2>/dev/null
    fi
    
    # Clean the tracker
    sed -i "\|^$logfile:$pid|d" "$PID_TRACKER"
    echo "Stopped $logfile"
  else
    # Fallback: If PID is lost, try to find it by the logfile name in 'ps'
    local alt_pid=$(ps aux | grep "$logfile" | grep -v grep | awk '{print $2}')
    if [[ -n "$alt_pid" ]]; then
       kill -9 $alt_pid && echo "Found and stopped via fallback."
    fi
  fi
}



cf_tunnel(){
  if [[  $# -lt 2 ]];then
    echo "usage: cf_tunnel output_var port"
    return
  fi

  echo "First arg: $1"
  local output_var=$1
  local port=$2

  echo "The rest: $all_after_second"
  local all_after_second="${@:3}"



  local CLOUDFLARED_LOG="/tmp/cf-$port.log"
  echo cloudflared tunnel --url localhost:$port $all_after_second --logfile $CLOUDFLARED_LOG
  ps_kill "cloudflared tunnel --url localhost:$port"
  if [[ -f "$CLOUDFLARED_LOG" ]] ; then rm $CLOUDFLARED_LOG || true;fi
  nohup_run "/dev/null" "cloudflared tunnel --url localhost:$port $all_after_second --logfile $CLOUDFLARED_LOG"



  WAIT_TIMEOUT=60
  #echo "Waiting up to $WAIT_TIMEOUT seconds for cloudflared public URL in $CLOUDFLARED_LOG"
  #exit 0
  END_TIME=$(( $(date +%s) + WAIT_TIMEOUT ))
  PUBLIC_URL=""

  while [ "$(date +%s)" -le "$END_TIME" ]; do
    if [[ ! -f $CLOUDFLARED_LOG ]];then
      echo "Cannot find $CLOUDFLARED_LOG"
      sleep 1
    else
      # Regex matches standard TryCloudflare URLs
      PUBLIC_URL=$(grep -Eo 'https?://[A-Za-z0-9.-]+\.trycloudflare\.com' "$CLOUDFLARED_LOG" | head -n1 || true)
      if [ -n "$PUBLIC_URL" ]; then break; fi
      sleep 1 
    fi 

  done
  echo $PUBLIC_URL
  eval "$output_var='$PUBLIC_URL'"
}


find_cf_url(){
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 CLOUDFLARED_LOG return_var"
        return 0
    fi 

    CLOUDFLARED_LOG=$1
    return_var=$2

    if [[ ! -f $CLOUDFLARED_LOG ]];then
        echo "Cannot find $CLOUDFLARED_LOG"
        return 0
    fi 

    WAIT_TIMEOUT=60
    #echo "Waiting up to $WAIT_TIMEOUT seconds for cloudflared public URL in $CLOUDFLARED_LOG"
    #exit 0
    END_TIME=$(( $(date +%s) + WAIT_TIMEOUT ))
    PUBLIC_URL=""

    while [ "$(date +%s)" -le "$END_TIME" ]; do
        # Regex matches standard TryCloudflare URLs
        PUBLIC_URL=$(grep -Eo 'https?://[A-Za-z0-9.-]+\.trycloudflare\.com' "$CLOUDFLARED_LOG" | head -n1 || true)
        if [ -n "$PUBLIC_URL" ]; then break; fi
        sleep 1
    done
    echo $PUBLIC_URL
    
    # --- 7. Connectivity Verification ---
    echo "=== Verifying external connectivity ==="
    # Wait a few seconds for DNS propagation/tunnel registration
    sleep 4 

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PUBLIC_URL" || true)

    if [[ "$HTTP_CODE" =~ ^2|3|4 ]]; then
        echo "✅ Cloudflared tunnel is reachable: HTTP $HTTP_CODE"
    else
        echo "⚠️  Cloudflared tunnel status: HTTP $HTTP_CODE"
        echo "    (If 000, the tunnel process might have died or is blocked by firewall)"
    fi


    eval "$2='$PUBLIC_URL'"
}




create_cf_tunnel(){

    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 port return_var"
        return 0
    fi 
    PORT=$1
    return_var=$2
    CLOUDFLARED_LOG="/tmp/cloudflared-tunnel-$PORT.log"
    WAIT_TIMEOUT=60


    if command -v cloudflared >/dev/null 2>&1; then
        echo "✅ cloudflared is installed."
        CLOUDFLARED_INSTALLED=true
    else
        echo "⚠️ cloudflared not found. Will install."
        echo "=== Installing cloudflared ==="
        # gh_install cloudflare/cloudflared cloudflared-linux-amd64 /tmp/cloudflared && chmod +x /tmp/cloudflared
        # cp /tmp/cloudflared $DIR/
    fi


    # --- 2. Cleanup & Port Release ---
    echo "⚠️Cleanup & Port Release"
    kill_program "cloudflared tunnel --url "http://127.0.0.1:$PORT""
    # --- 3. Install Dependencies (if missing) ---

    if ss -ltnp | grep -q "127.0.0.1:$PORT\\b"; then
        echo "✅ 127.0.0.1:$PORT is healthy"
    else
        echo "❌ 127.0.0.1:$PORT is unhealthy"
    fi

    # --- 5. Start Cloudflared Tunnel ---
    echo "=== Starting cloudflared tunnel ==="
    mkdir -p "$(dirname "$CLOUDFLARED_LOG")"
    : > "$CLOUDFLARED_LOG"

    # 1. NO_PROXY: Ensures connection to localhost doesn't go through environment proxies.
    # 2. setsid: Detaches process from shell.
    # 3. url "http://127.0.0.1": Explicitly forces IPv4 HTTP connection (fixes connection refused errors).
    # 4. --no-autoupdate: Prevents process restart/PID changes during startup.
    env NO_PROXY="localhost,127.0.0.1" \
    nohup setsid cloudflared tunnel \
        --url "http://127.0.0.1:$PORT" \
        --no-autoupdate \
        --logfile "$CLOUDFLARED_LOG" \
        > /dev/null 2>&1 &

    CF_PID=$!
    disown $CF_PID # Remove from jobs list

    sleep 1


    # --- 6. Wait for Public URL ---
    echo "Waiting up to $WAIT_TIMEOUT seconds for cloudflared public URL..."
    find_cf_url $CLOUDFLARED_LOG PUBLIC_URL

    eval "$2='$PUBLIC_URL'"


    # --- 8. Final Output & JSON Update ---
    echo
    echo "=== Setup complete ==="
    echo "Exposed Local:    127.0.0.1:$PORT"
    echo "Public URL:    $PUBLIC_URL"
    echo "Log File:      $CLOUDFLARED_LOG"
    echo "" # Newline for clean exit


}
