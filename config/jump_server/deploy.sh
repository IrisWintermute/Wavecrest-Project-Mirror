#!/bin/bash

set -euo pipefail

TEMPLATE="config/jump_server/template.yaml"
STACK_NAME=jump-server

STACK_EXISTS=$(aws cloudformation list-stacks --output text)
echo "checking if $STACK_NAME exists"
echo "$STACK_EXISTS"
if [ "$STACK_EXISTS" == "" ] ; then
    # "org-vpc"
    VPC_ID=vpc-0507b30241a1b5d56
    # "private-org-opsSubnet1"
    SUBNET=subnet-0d9541b56ee0d37e6
    
    echo "Subnet = $SUBNET"
    echo "VpcId = $VPC_ID"
    echo
    
    echo Deploying Stack $STACK_NAME...
    
    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE" \
        --parameter-overrides Subnet="$SUBNET" VpcId="$VPC_ID" \
        --capabilities CAPABILITY_NAMED_IAM \
        --no-fail-on-empty-changeset
    
    echo
    echo "Jump server running"
    echo
else
    echo "Stack $STACK_NAME already exists."
    echo
fi