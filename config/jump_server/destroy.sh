#!/bin/bash

set -euo pipefail

STACK_NAME=jump-server

STACK_EXISTS=$(aws cloudformation describe-stack-instances --filters Name=tag:Name,Values="$STACK_NAME" Name=instance-state-code,Values=16 --output text)
echo "$STACK_EXISTS"
if ["$STACK_EXISTS" != ""]; then
    echo Destroying Stack $STACK_NAME...

    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" 

    echo
    echo "Jump server with name $STACK_NAME destroyed."
    echo
else
    echo "Stack $STACK_NAME does not exist."
    echo
fi