#!/bin/bash

set -euo pipefail

TEMPLATE="config/jump_server/template.yaml"
STACK_NAME=jump-server

STACK_EXISTS=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE --output text)
echo "checking if $STACK_NAME exists"
echo "$STACK_EXISTS"
if [ "$STACK_EXISTS" == "" ] ; then
    # "org-vpc"
    VPC_ID=vpc-0507b30241a1b5d56
    # "private-org-opsSubnet1"
    SUBNET=subnet-0a1404af01a0b805c
    
    echo "Subnet = $SUBNET"
    echo "VpcId = $VPC_ID"
    echo
    
    echo Deploying Stack $STACK_NAME...
    
    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE" \
        --parameter-overrides Subnet="$SUBNET" VpcId="$VPC_ID" \
        --capabilities CAPABILITY_NAMED_IAM \
        --no-fail-on-empty-changeset \
        --output table

    echo "creating endpoints for the jump server"
    echo

    aws ec2 create-vpc-endpoint \
        --service-name com.amazonaws.eu-west-1.ssm \
        --vpc-endpoint-type Interface \
        --vpc-id "$VPC_ID" \
        --subnet-ids "$SUBNET" \
        --output table
    
    aws ec2 create-vpc-endpoint \
        --service-name com.amazonaws.eu-west-1.ssmmessages \
        --vpc-endpoint-type Interface \
        --vpc-id "$VPC_ID" \
        --subnet-ids "$SUBNET" \
        --output table

    aws ec2 create-vpc-endpoint \
        --service-name com.amazonaws.eu-west-1.ec2 \
        --vpc-endpoint-type Interface \
        --vpc-id "$VPC_ID" \
        --subnet-ids "$SUBNET" \
        --output table
    
    aws ec2 create-vpc-endpoint \
        --service-name com.amazonaws.eu-west-1.ec2messages \
        --vpc-endpoint-type Interface \
        --vpc-id "$VPC_ID" \
        --subnet-ids "$SUBNET" \
        --output table

    echo
    echo "Jump server running"
    echo
else
    echo "Stack $STACK_NAME already exists."
    echo
fi