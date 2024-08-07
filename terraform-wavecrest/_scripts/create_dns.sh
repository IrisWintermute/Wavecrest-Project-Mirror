#!/usr/bin/env bash

### Set variables ###
# if called from github actions
if [[ "${1}" != "" ]]; then
    envname=${1}
    short_region=${2}
    colour=${3}
    if [[ "${3}" == "" ]]; then
        echo "Not enough arguments. Usage: create_dns.sh <envname> <short_region> <colour>"
        exit 1
    fi
else
    # if called from the config directory
    directory=$(basename ${PWD})
    envname=$(cut -d'-' -f1 <<< $directory)
    short_region=$(cut -d'-' -f2 <<< $directory)
    colour=$(cut -d'-' -f3 <<< $directory)
fi


declare -A AWS_ACCOUNT_LOOKUP
AWS_ACCOUNT_LOOKUP["dev"]="308891343985"
AWS_ACCOUNT_LOOKUP["tst"]="861233633704"
AWS_ACCOUNT_LOOKUP["ops"]="579662209389"
AWS_ACCOUNT_LOOKUP["prd"]="979892364775"



declare -A AWS_DOMAIN_LOOKUP
AWS_DOMAIN_LOOKUP["dev"]="dev.network.wavecrest.com."
AWS_DOMAIN_LOOKUP["tst"]="tst.network.wavecrest.com."
AWS_DOMAIN_LOOKUP["ops"]="ops.network.wavecrest.com."
AWS_DOMAIN_LOOKUP["prd"]="network.wavecrest.com."
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_LOOKUP[${envname}]}

# Check if jq command exists
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq."
    exit 1
fi

check_account=$(aws sts get-caller-identity | jq .Account -r)
if [[ "$check_account" != "$AWS_ACCOUNT_ID" ]]; then
    echo "You are logged into the wrong AWS account. Please check your credentials and try again."
    exit 1
fi

get_hosted_zone_id() {
    local domain="$1"
    local hosted_zone_id

    # Call aws route53 list-hosted-zones and parse JSON output using jq
    hosted_zone_id=$(aws route53 list-hosted-zones | jq -r --arg domain "$domain" '.HostedZones[] | select(.Name == $domain) | .Id')

    echo "$hosted_zone_id"
}

upsert_cname_record() {
    local domain="$1"
    local target_domain="$2"

    # UPSERT the CNAME record
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch '{
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "'"$domain"'",
                        "Type": "CNAME",
                        "TTL": 60,
                        "ResourceRecords": [
                            {
                                "Value": "'"$target_domain"'"
                            }
                        ]
                    }
                }
            ]
        }'
}

echo "Promoting $colour-$short_region to accept traffic for $short_region"

domain=${AWS_DOMAIN_LOOKUP[${envname}]}

hosted_zone_id=$(get_hosted_zone_id ${domain})
echo "Hosted zone ID for ${domain} is $hosted_zone_id"

upsert_cname_record "slb-${short_region}.${domain}" "slb-${colour}-${short_region}.${domain}"
upsert_cname_record "slb-private-${short_region}.${domain}" "slb-private-${colour}-${short_region}.${domain}"
upsert_cname_record "_sip._udp.slb.${short_region}.${domain}" "_sip._udp.slb.${colour}.${short_region}.${domain}"
upsert_cname_record "_sip._tcp.slb.${short_region}.${domain}" "_sip._tcp.slb.${colour}.${short_region}.${domain}"

for i in {0..2}; do
    upsert_cname_record "${envname}-${short_region}-slb-${i}.${domain}" "${envname}-${short_region}-${colour}-slb-${i}.${domain}"
done
