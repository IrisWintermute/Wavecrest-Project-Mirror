#!/usr/bin/env bash

arg=$1
rtype = $2
if [[ "$arg" = "start" ]]; then
    git pull
    python3 main/manager.py "$rtype"
fi
if [[ "$arg" = "kill" ]]; then
    pkill python3
fi
