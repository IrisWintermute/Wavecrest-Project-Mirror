#!/usr/bin/env bash

arg = $(1)
if [["${arg}" = "start"]]; then
    git pull
    python3 main/manager.py
fi
if [["${arg}" = "kill"]]; then
    kill 15 $(pidof python3)
fi
if [["${arg}" = "reload"]]; then
    kill 1 $(pidof python3)
fi
