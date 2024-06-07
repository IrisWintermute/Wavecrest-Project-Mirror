#!/usr/bin/env bash

envname=${1:-ops}
short_region=${2:-ew1}
colour=${3:-core}
auto=${4:-auto} # or Setup or check
config_dir=${5}
called_action=${6}

core_reg="ew1"

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
    echo "${RED}${BLACK_BG}${1}${RESET}"
}

if [[ ! -f ./_scripts/region.sh ]]; then
    warnlog "ERROR: Please run this script from the config directory"
    exit 1
fi

if [[ -z "${envname}" ]] || [[ -z "${short_region}" ]] || [[ -z "${colour}" ]]; then
    warnlog "Usage: deploy.sh <envname> <short_region> <colour> <auto> <config_dir> <action>"
    warnlog "e.g. deploy.sh tst ew1 green"
    warnlog "or: deploy.sh dev ew1 blue check"
    exit 1
fi

try() {
   "$@"
    status=$?
    if [ ${status} -ne 0 ]; then
        warnlog "Command failure (${status}) at line ${BASH_LINENO[0]}: $@"
        exit 1
    fi
}

run_terraform () {
    config_dir=${1}
    action=${2:-default}

    config_short_region=$(cut -d'-' -f2 <<< ${config_dir})

    config_region=$(./_scripts/region.sh ${config_short_region})
    AWS_REGION="${config_region}"

    cd ${1}

    if [[ ${action} != "default" ]]; then
        boldlog "====> ${config_dir} ${action} <======================================================"
        try make reconfig 2>&1 > /dev/null
        try make ${action}
    else
        boldlog "====> ${config_dir} <======================================================"
        try make reconfig 2>&1 > /dev/null
        try make plan | grep -E -v '^........data|^........module' #stupid control characters in output
        if [[ "${auto}" != "check" ]]; then
            try make apply
        fi
    fi

    cd ..
}

if [[ "${auto}" != "Setup" ]]; then
    log "${auto} mode using Github Actions"
else
    log "Interactive mode - prompts enabled"
    log "About to deploy ${envname} ${short_region} ${colour} environment - are you sure? (y/n)"
    read answer
    if [ "$answer" != "${answer#[Yy]}" ] ;then
        log "Deploying ${envname} ${short_region} ${colour} environment"
    else
        log "Exiting"
        exit 1
    fi
fi

AWS_PROFILE=${envname}
if [[ "${auto}" == "Setup" ]]; then
    try eval "$(aws configure export-credentials --profile ${envname} --format env)"
else
    log "Setting temporary AWS CLI profile ${envname}"
    central_core=$(./_scripts/region.sh ${core_reg})
    try eval "$(aws configure set region ${central_core} --profile ${envname})"
    aws configure list
fi

#if called from GH Action terraform-single-part.yml
if [[ "${config_dir}" != "" ]]; then
    if [[ "${config_dir}" =~ "common" ]]; then
        log "Running single config directory ${envname}-${short_region}-${config_dir} ${called_action} only"
        conf_dir=${envname}-${short_region}-${config_dir}
    else
        log "Running single config directory ${envname}-${short_region}-${colour}-${config_dir} ${called_action} only"
        conf_dir=${envname}-${short_region}-${colour}-${config_dir}
    fi

    if [[ "${called_action}" == "provision" ]]; then
    boldlog "${auto} setup ${envname} ssh shim"
    run_terraform ${envname}-${short_region}-common-setup ssh
    fi

    if [[ "${called_action}" == "apply" ]]; then
        run_terraform ${conf_dir} plan
        try run_terraform ${conf_dir} apply
    else
        try run_terraform ${conf_dir} ${called_action}
    fi
    exit 0
fi

boldlog "${auto} setup ${envname} ssh shim"
run_terraform ${envname}-${short_region}-common-setup ssh

boldlog "${auto} deploy ${envname} common components"
run_terraform ${envname}-${short_region}-common-setup

boldlog "${auto} deploy ${envname} VPC and networking"
run_terraform ${envname}-${short_region}-${colour}-vpc

boldlog "${auto} deploy ${envname}-${short_region}-${colour} Jump Server"
run_terraform ${envname}-${short_region}-${colour}-jump

boldlog "${auto} deploy ${envname}-${short_region}-${colour} AI Server"
run_terraform ${envname}-${short_region}-${colour}-ai

boldlog "Finished with ${envname} ${short_region} ${colour} environment"
