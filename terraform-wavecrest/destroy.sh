#!/usr/bin/env bash

envname=${1:-ops}
short_region=${2:-ew1}
colour=${3:-core}
force=${4:-true}
core_reg=${5:-ew1}
auto=${6:-auto} #can be interactive

#setup colours and smart terminal outputs
if [[ "${TERM}" = "xterm" ]] || [[ "${TERM}" = "xterm-256color" ]] || [[ "${TERM}" = "dumb" ]]; then
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
        echo "${DIM}${YELLOW}${BLACK_BG}${1}${RESET}"
}

boldlog () {
        echo "${BOLD}${CYAN}${BLACK_BG}${1}${RESET}"
}

warnlog () {
        echo "${BOLD}${RED}${BLACK_BG}${1}${RESET}"
}

if [[ ! -f ./_scripts/region.sh ]]; then
    warnlog "ERROR: Please run this script from the config directory"
    exit 1
fi

if [[ -z "${envname}" ]] || [[ -z "${short_region}" ]] || [[ -z "${colour}" ]]; then
    warnlog "Usage: destroy.sh envname short_region colour <force-destroy> <core-reg>"
    warnlog "e.g. destroy.sh ops ew1 core"
    log "force-destroy is optional destroy of tgw and vpc and it defaults to false"
    log "core-reg is optional and defaults to ew1"
    exit 1
fi

try() {
   "$@"
    status=$?
    if [ ${status} -ne 0 ]; then
        log "Command failure (${status}) at line ${BASH_LINENO[0]}: $@"
        exit 1
    fi
}

destroy_terraform () {
    config_dir=${1}
    config_short_region=$(cut -d'-' -f2 <<< ${config_dir})

    config_region=$(./_scripts/region.sh ${config_short_region})
    AWS_REGION="${config_region}"

    if [[ -d ${1} ]]; then
        boldlog "====> ${config_dir} <======================================================"
        cd ${config_dir}
        try make reconfig 2>&1 > /dev/null
        try make destroy-plan | grep -E -v '^........data|^........module' #stupid control characters in output
        make destroy-apply
        cd ..
    else
        log "Directory ${config_dir} does not exist - skipping"
    fi
}

run_terraform () {
    config_dir=${1}

    config_short_region=$(cut -d'-' -f2 <<< ${config_dir})

    config_region=$(./_scripts/region.sh ${config_short_region})
    AWS_REGION="${config_region}"

    if [[ -d ${1} ]]; then
    boldlog "====> ${config_dir} <======================================================"
    cd ${config_dir}

    try make reconfig 2>&1 > /dev/null
    make plan | grep -E -v '^........data|^........module' #stupid control characters in output
    make apply

    cd ..
    else
        log "Directory ${config_dir} does not exist - skipping"
    fi
}

export AWS_PROFILE=${envname}
if [[ "${auto}" = "auto" ]]; then
    log "${auto} mode using Github Actions"
else
    log "Interactive mode - prompts enabled"
    log "About to destroy ${envname} ${short_region} ${colour} environment - are you sure? (y/n)"
    read answer
    if [ "$answer" != "${answer#[Yy]}" ] ;then
        log "Destroying ${envname} ${short_region} ${colour} environment"
    else
        log "Exiting"
        exit 1
    fi
fi

# Don't delete secrets and keys unless you really mean it!
# No option to delete ${envname}-common-setup here - must be done manually

central_core=$(./_scripts/region.sh ${core_reg})
if [[ "${auto}" == "Setup" ]]; then
    try eval "$(aws configure export-credentials --profile ${envname} --format env)"
else
    log "Setting temporary AWS CLI profile ${envname}"
    try eval "$(aws configure set region ${central_core} --profile ${envname})"
    aws configure list
fi

#reverse order of deploy to avoid dependencies

boldlog "Destroy ${envname} Core AI server"
destroy_terraform ${envname}-${core_reg}-core-ai

boldlog "Destroy ${envname} Core Jump server"
destroy_terraform ${envname}-${core_reg}-core-jump

boldlog "Destroy ${envname} VPC and networking"
destroy_terraform ${envname}-${core_reg}-core-vpc

boldlog "Destroy ${envname} common"
destroy_terraform ${envname}-${core_reg}-common-setup
