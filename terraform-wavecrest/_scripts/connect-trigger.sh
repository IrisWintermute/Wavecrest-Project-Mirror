#!/usr/bin/env bash

### Check they have already set up the password shim ###

if [[ ! -L ~/.ssh/ssh_shim.sh ]]; then
    echo "ERROR: Please set up the ssh shim as per the common-setup instructions."
    exit 1
fi

### Set variables ###

directory=$(basename ${PWD})
envname=$(cut -d'-' -f1 <<< $directory)
short_region=$(cut -d'-' -f2 <<< $directory)
colour=$(cut -d'-' -f3 <<< $directory)
part=$(cut -d'-' -f4 <<< $directory)

core_reg="ew1" # core region
core_region="eu-west-1" # core region

export AWS_REGION="eu-west-1"  # core region

export region=${1} # what is this used for?

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

###

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
        echo "${GREEN}${BLACK_BG}${1}${RESET}"
}

command_ssh () {
    if [[ "${debug}" == "true" ]]; then
        log "SSH: $@"
    fi
    output=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${jump_host} -t "$@")
    status=$?

    if [[ "${fail_ok}" == "true" ]]; then
        #revese the status so that we can exit on success
        if [ ${status} -ne 1 ]; then
            log "Command succeeded (${status}) at line ${BASH_LINENO[0]}"
            exit 0
        fi
    fi

    if [ ${status} -ne 0 ]; then
        if [[ "${debug}" == "true" ]]; then
            log "Command failure (${status}) at line ${BASH_LINENO[0]}: $@"
        else
            log "Command failure (${status}) at line ${BASH_LINENO[0]}"
        fi
    fi
}

get_secret () {
    secret_name=${1}
    secret_key=${2}
    secret=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --query SecretString --output text --region ${core_region}| jq -r .${secret_key})
    echo ${secret}
}

### Start script ###

log "Gathering variables"

# shared vars
export trigger_scripts_location="$(realpath ../../../tf-connect-lambda/scripts)"

export PROVISIONING_SECRET="$(get_secret ${envname}/provisioning_api api_key)"
if [[ "$envname" == "prd" ]]; then
    domain="network.wavecrest.com"
else
    domain="${envname}.network.wavecrest.com"
fi
export PROVISIONING_LAMBDA="provisioning-core-${core_reg}.${domain}"
export TRIGGER_LAMBDA="trigger.${colour}.${short_region}.${domain}"
export provision_var_string="SERVICE_SHORT_REGION=${short_region} SERVICE_COLOUR=${colour} PROVISIONING_SECRET=${PROVISIONING_SECRET} PROVISIONING_LAMBDA=${PROVISIONING_LAMBDA} TRIGGER_LAMBDA=${TRIGGER_LAMBDA}"


## set up provisioner
export jump_host="admin@${envname}-${core_reg}-core-jump"
log "Setting up provisioner on jump host ${jump_host}"

command_ssh 'sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get install -qq --assume-yes curl jq rsync'


log "Set up temp directory for scripts"
command_ssh 'if [[ -d /tmp/trigger ]]; then rm -rf /tmp/trigger; else echo "No existing /tmp/trigger directory"; fi'
command_ssh 'mkdir -p /tmp/trigger'

log "RSYNC: rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${trigger_scripts_location}/ ${jump_host}:/tmp/trigger/"
rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${trigger_scripts_location}/ ${jump_host}:/tmp/trigger/

log "Running provisioner on jump host ${jump_host}"

command_ssh "cd /tmp/trigger && ${provision_var_string} ./trigger_provisioning.sh > /tmp/trigger/provision.log 2>&1"

if [[ "${debug}" == "true" ]]; then
    log "Provisioner output:"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${jump_host} -t 'cat /tmp/trigger/provision.log'
fi

log "Finished"
