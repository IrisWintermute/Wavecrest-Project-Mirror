#!/usr/bin/env bash

# From: https://cloudsoft.io/blog/remote-access-to-ec2-instances-the-easy-and-secure-way

# Put into .ssh/config something like this:
# host i-* mi-*
#   ProxyCommand sh -c "~/bin/ssm-ssh-shim.sh '%r' '%h' '%p' YOUR_IDENTITY"
#
# Then you can SSH-via-SessionManager using a command like this:
# ssh ec2-user@i-07e9bd6d3497545cd
# or
# ssh ec2-user@i-07e9bd6d3497545cd,eu-west-2
# SCP works too:
# scp ec2-user@i-07e9bd6d3497545cd,eu-west-2:.bash_history history

set -e

user="${1}"
target="${2}"
port="${3}"
ssh_key="${4}"
envname="${5}"

debug="${debug:-false}"

declare -A AWS_ACCOUNTID_LOOKUP
AWS_ACCOUNTID_LOOKUP["308891343985"]="dev"
AWS_ACCOUNTID_LOOKUP["861233633704"]="tst"
AWS_ACCOUNTID_LOOKUP["579662209389"]="ops"
AWS_ACCOUNTID_LOOKUP["979892364775"]="prd"

declare -A REGION_LOOKUP
REGION_LOOKUP["ew1"]="eu-west-1"
REGION_LOOKUP["ew2"]="eu-west-2"
REGION_LOOKUP["ec1"]="eu-central-1"
REGION_LOOKUP["se1"]="sa-east-1"


#setup colours and smart terminal outputs
if [[ "${TERM}" = "xterm" ]] || [[ "${TERM}" = "xterm-256color" ]] || [[ "${TERM}" = "cygwin" ]]; then
    #e.g.  echo "${RED}red text ${GREEN}green text${RESET}"
    BLACK=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    LIGHT_BLUE="${CYAN}"
    WHITE=$(tput setaf 7)
    DEFAULT=$(tput setaf 9)

    BLACK_BG=$(tput setab 0)
    RED_BG=$(tput setab 1)
    GREEN_BG=$(tput setab 2)
    YELLOW_BG=$(tput setab 3)
    BLUE_BG=$(tput setab 4)
    MAGENTA_BG=$(tput setab 5)
    CYAN_BG=$(tput setab 6)
    LIGHT_BLUE_BG="${CYAN_BG}"
    WHITE_BG=$(tput setab 7)
    DEFAULT_BG=$(tput setab 9)

    BOLD=$(tput bold)
    DIM=$(tput dim)
    REVERSE=$(tput rev)
    #make sure reset is last in case of sourcing library and debugging
    RESET=$(tput sgr0)
fi

log () {
    echo >&2 "${YELLOW}${BLACK_BG}${1}${RESET}"
}

debuglog () {
    if [[ "${debug}" == "true" ]]; then
        echo >&2 "${CYAN}${BLACK_BG}${1}${RESET}"
    fi
}

usage () {
    echo "Usage: $0 <user> <target> <port> [ssh_key]"
    echo "  user: user to connect as"
    echo "  target: instance id, private ip address, or private ip dns entry"
    echo "  port: port to connect to (usually 22)"
    echo "  ssh_key: optional ssh key to send to Ubuntu instance"
    echo ""
    echo "Example targets:"
    echo "  i-1234567890abcdef0"
    echo "  i-1234567890abcdef0,ew2"
    echo "  i-1234567890abcdef0,eu-west-2"
    echo "  ip-10-151-1-107.eu-west-1.compute.internal"
    echo "  dev-ew1-blue-jump (if more than one then just first one in list)"
    echo ""

    # reset back to original region
    export AWS_REGION="${original_region}"
    exit 1
}

if [[ "${1}" == "" ]]; then
    usage
fi


#check account matches
if [[ "${envname}" != "" ]]; then
    eval "$(aws configure export-credentials --profile ${envname} --format env)"
fi

aws sts get-caller-identity
check_account=$(aws sts get-caller-identity | jq .Account -r)
export AWS_ACCOUNT=${AWS_ACCOUNTID_LOOKUP[${check_account}]}

if [[ "${AWS_ACCOUNT}" == "" ]]; then
    log "You don't seem to be logged into a Connect AWS account. Please check your credentials and try again."
    exit 1
else
    debuglog "You are logged into the ${AWS_ACCOUNT} AWS account."
fi

#set default region from ${AWS_REGION} or use eu-west-1 if not set
export AWS_REGION="${AWS_REGION:-eu-west-1}"
original_region="${AWS_REGION}" # reset back to this after script
debuglog "Current AWS region is ${AWS_REGION}"

# targets can be:
#  i-1234567890abcdef0 (current region of AWS_REGION or AWS_REGION)
#  i-1234567890abcdef0,ew2
#  i-1234567890abcdef0,eu-west-2
#  ip-10-151-1-107.eu-west-1.compute.internal
#  dev-ew1-blue-jump (if more than one then just first one in list)

if [[ "${target}" =~ (i-[0-9a-f]+)(,([a-z0-9-]+))? ]]; then
    # target is instance id, possibly with region suffix after comma
    instance_id="${BASH_REMATCH[1]}"
    region="${BASH_REMATCH[3]}"
    debuglog "Found region suffix: ${region}"
    if [[ "${region}" != "" ]]; then
        if [[ "${region}" =~ ^[a-z0-9]{2}-[a-z0-9]+-[0-9]$ ]]; then
            export AWS_REGION="${region}"
            debuglog "Setting AWS_REGION to ${AWS_REGION}"
        elif [[ "${region}" =~ ^[a-z0-9]{3}$ ]]; then
            export AWS_REGION="${REGION_LOOKUP[${region}]}"
            debuglog "Setting AWS_REGION to ${AWS_REGION}"
        else
            log "Invalid region: ${BASH_REMATCH[3]}"
            usage
            exit 1
        fi
    fi

    # target is server name like dev-ew1-blue-jump
elif [[ "${target}" =~ ${AWS_ACCOUNT}-([a-z0-9]{3})-([a-z0-9-]+)? ]]; then
    export AWS_REGION="${REGION_LOOKUP[${BASH_REMATCH[1]}]}"
    debuglog "Setting AWS_REGION to ${AWS_REGION}"
    instance_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${target}" "Name=instance-state-name,Values=running" --output text --query "Reservations[0].Instances[0].InstanceId" --region "${AWS_REGION}")
    if [[ "${instance_id}" == "None" ]]; then
        log "Could not find instance id for tag name ${target} in region ${AWS_REGION}"
        usage
        exit 1
    else
        debuglog "Found instance id for ${target} : ${instance_id}"
    fi

    #target is private ip address DNS entry
elif [[ "${target}" =~ ^ip-([0-9]+-[0-9]+-[0-9]+-[0-9]+)\.([a-z0-9-]+)\.compute\.internal$ ]]; then
    debuglog "Setting AWS_REGION to ${BASH_REMATCH[2]}"
    export AWS_REGION="${BASH_REMATCH[2]}"
    ip_address="${BASH_REMATCH[1]//-/.}"
    debuglog "Looking up instance id for private ip ${ip_address}"
    instance_id=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=${ip_address}" "Name=instance-state-name,Values=running" --output text --query "Reservations[0].Instances[0].InstanceId" --region "${AWS_REGION}")
    if [[ "${instance_id}" == "None" ]]; then
        log "Could not find instance id for ${target} in region ${AWS_REGION}"
        usage
        exit 1
    else
        debuglog "Found instance id for private ip dns ${target}: ${instance_id}"
    fi

    #target is private ip address, maybe with a suffix region
elif [[ "${target}" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(,([a-z0-9-]+))?$ ]]; then
    instance_ip="${BASH_REMATCH[1]}"
    region="${BASH_REMATCH[3]}"
    if [[ "${region}" != "" ]]; then
        debuglog "Found region suffix: ${region}"
        if [[ "${region}" =~ ^[a-z0-9]{2}-[a-z0-9]+-[0-9]$ ]]; then
            export AWS_REGION="${region}"
            debuglog "Setting AWS_REGION to ${AWS_REGION}"
        elif [[ "${region}" =~ ^[a-z0-9]{3}$ ]]; then
            export AWS_REGION="${REGION_LOOKUP[${region}]}"
            debuglog "Setting AWS_REGION to ${AWS_REGION}"
        else
            log "Invalid region found - using current AWS_REGION ${AWS_REGION}"
        fi
    fi
    instance_id=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=${instance_ip}" "Name=instance-state-name,Values=running" --output text --query "Reservations[0].Instances[0].InstanceId" --region "${AWS_REGION}")
    if [[ "${instance_id}" == "None" ]]; then
        log "Could not find instance id for ${target}"
        usage
        exit 1
    else
        debuglog "Found instance id for ${target}: ${instance_id}"
    fi

#else give up
else
    log "Invalid target: ${target}"
    usage
    exit 1
fi

if [[ "${ssh_key}" != "" ]]; then
ssh_key_file=~/.ssh/${ssh_key}.pub
debuglog "Sending personal SSH public key ..."
debuglog "aws ec2-instance-connect send-ssh-public-key --instance-id ${instance_id} --instance-os-user ${user} --ssh-public-key file://${ssh_key_file} --region ${AWS_REGION}"
aws ec2-instance-connect send-ssh-public-key \
	--instance-id "${instance_id}" \
	--instance-os-user "${user}" \
	--ssh-public-key "file://${ssh_key_file}" \
    --region "${AWS_REGION}"
fi

log "Starting session ${user}@${instance_id},${AWS_REGION},${envname} ..."
exec aws ssm start-session --target "${instance_id}" --document-name AWS-StartSSHSession --parameters portNumber="${port}" --region "${AWS_REGION}"

# reset back to original region
export AWS_REGION="${original_region}"