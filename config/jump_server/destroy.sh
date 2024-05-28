#!/bin/bash

set -euo pipefail

STACK_NAME=jump-server

STACK_EXISTS=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE --output table)
echo "checking if $STACK_NAME exists"
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