#!/usr/bin/env bash
set -e


chmod +x /opt/shell/*.sh

file_lock="/tmp/.docker-is-stated"

if [ ! -f $file_lock ]; then 
  echo "start task" > $file_lock
  /opt/shell/task.sh
fi
