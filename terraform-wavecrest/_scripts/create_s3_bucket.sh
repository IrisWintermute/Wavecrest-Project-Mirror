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

bucket_name="wavecrest-terraform-${envname}-${reg}"
ai_bucket_name="wavecrest-terraform-${envname}-${reg}-ai"

# Check if the bucket already exists
bucket_exists=false
if aws s3api head-bucket --bucket "$bucket_name" | cat 2>/dev/null; then
    bucket_exists=true
    echo "Bucket '$bucket_name' already exists."
else
    echo "Bucket '$bucket_name' does not exist. Creating..."
fi

# If the bucket doesn't exist, create it
if [ "$bucket_exists" = false ]; then
    aws s3api create-bucket --bucket "$bucket_name" --create-bucket-configuration LocationConstraint=$region
    echo "Bucket '$bucket_name' created in region '$region'."
fi

ai_bucket_exists=false
if aws s3api head-bucket --bucket "$ai_bucket_name" | cat 2>/dev/null; then
    ai_bucket_exists=true
    echo "Bucket '$ai_bucket_name' already exists."
else
    echo "Bucket '$ai_bucket_name' does not exist. Creating..."
fi

if [ "$ai_bucket_exists" = false ]; then
    aws s3api create-bucket --bucket "$ai_bucket_name" --create-bucket-configuration LocationConstraint=$region
    echo "Bucket '$ai_bucket_name' created in region '$region'."
fi

# Enable versioning on the bucket
aws s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
echo "Versioning enabled on bucket '$bucket_name'."
aws s3api put-bucket-versioning --bucket "$ai_bucket_name" --versioning-configuration Status=Enabled
echo "Versioning enabled on bucket '$bucket_name'."

# Enable encryption on the bucket
aws s3api put-bucket-encryption --bucket "$bucket_name" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws s3api put-bucket-encryption --bucket "$ai_bucket_name" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

echo "Encryption enabled on bucket '$bucket_name'."