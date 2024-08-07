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

export region=${1}

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
    secret_region=${3:-${region}}
    secret=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --query SecretString --output text --region ${secret_region}| jq -r .${secret_key})
    echo ${secret}
}

### Start script ###

log "Gathering variables"

# shared vars
export scripts_location="$(realpath ../../../voicenet_${part}/sql)"

## set up provisioner
export jump_host="admin@${envname}-${short_region}-${colour}-jump"
log "Setting up ${part} provisioner on jump host ${jump_host}"

command_ssh 'sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get install -qq --assume-yes rsync'

log "RSYNC: rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${scripts_location}/ ${jump_host}:/tmp/${part}"
rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${scripts_location}/ ${jump_host}:/tmp/${part}

log "Running provisioner on jump host ${jump_host}"

command_ssh "cd /tmp/${part} && ./cloud-provision.sh > /tmp/${part}_provision.log 2>&1"

if [[ "${debug}" == "true" ]]; then
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${jump_host} -t "cat /tmp/${part}_provision.log"
fi

log "Finished"
