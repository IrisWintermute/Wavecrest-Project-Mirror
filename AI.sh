#!/usr/bin/env bash

if [["$1" = "start"]]; then
    git pull
    python3 main/manager.py
fi
if [["$1" = "kill"]]; then
    kill 15 $(pidof python3)
fi
if [["$1" = "reload"]]; then
    kill 1 $(pidof python3)
fi
