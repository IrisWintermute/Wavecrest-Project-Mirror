#!/bin/bash

set -euo pipefail

TEMPLATE=template.yaml
STACK_NAME=jump-server

echo Linting template...
echo
cfn-lint $TEMPLATE

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
INSTANCE_ID=$(get_cfn_output "$STACK_NAME" 'InstanceId')
echo "Jump server running as instance $INSTANCE_ID"
echo