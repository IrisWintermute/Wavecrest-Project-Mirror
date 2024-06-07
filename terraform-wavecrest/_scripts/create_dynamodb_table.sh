#!/usr/bin/env bash

### Set variables ###

directory=$(basename ${PWD})
envname=$(cut -d'-' -f1 <<< $directory)
reg=$(cut -d'-' -f2 <<< $directory)
colour=$(cut -d'-' -f3 <<< $directory)
part=$(cut -d'-' -f4 <<< $directory)

region=$(../_scripts/region.sh ${reg})

declare -A AWS_ACCOUNT_LOOKUP
AWS_ACCOUNT_LOOKUP["dev"]="308891343985"
AWS_ACCOUNT_LOOKUP["tst"]="861233633704"
AWS_ACCOUNT_LOOKUP["ops"]="579662209389"
AWS_ACCOUNT_LOOKUP["prd"]="979892364775"

export AWS_ACCOUNT_ID=${AWS_ACCOUNT_LOOKUP[${envname}]}

check_account=$(aws sts get-caller-identity | jq .Account -r)
if [[ "$check_account" != "$AWS_ACCOUNT_ID" ]]; then
    echo "You are logged into the wrong AWS account. Please check your credentials and try again."
    exit 1
fi

### Start script ###

lock_table_name="${1:-terraform-base-infra}"

# Check if the DynamoDB table already exists
table_exists=false
if aws dynamodb describe-table --table-name "$lock_table_name" 2>/dev/null; then
    table_exists=true
    echo "DynamoDB table '$lock_table_name' already exists."
else
    echo "DynamoDB table '$lock_table_name' does not exist. Creating..."
fi

# If the table doesn't exist, create it
if [ "$table_exists" = false ]; then
    aws dynamodb create-table \
        --table-name "$lock_table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $region | cat
    echo "DynamoDB table '$lock_table_name' created."
fi