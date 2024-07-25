#!/usr/bin/env bash

arg=$1
if [[ "$arg" = "start" ]]; then
    git pull
    python3 main/manager.py
fi
if [[ "$arg" = "kill" ]]; then
    pkill python3
fi
