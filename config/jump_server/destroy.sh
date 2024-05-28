#!/bin/bash

set -euo pipefail

STACK_NAME=jump-server

echo Destroying Stack $STACK_NAME...

aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" 

echo
echo "Jump server with name $STACK_NAME destroyed."
echo