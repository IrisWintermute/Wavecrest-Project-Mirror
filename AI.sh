#!/usr/bin/env bash

if [$1 = "start"]
    git pull
    python3 main/manager.py
fi
if [$1 = "kill"]
    kill 15 $(pidof python3)
fi
if [$1 = "reload"]
    kill 1 $(pidof python3)
fi
