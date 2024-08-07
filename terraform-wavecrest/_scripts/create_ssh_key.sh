#!/usr/bin/env bash
auto=${1:-interactive}

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

#setup colours and smart terminal outputs
if [[ "${TERM}" = "xterm" ]] || [[ "${TERM}" = "xterm-256color" ]] || [[ "${TERM}" = "cygwin" ]]; then
    #e.g.  log "${RED}red text ${GREEN}green text${RESET}"
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

logwarn () {
        echo "${RED}${BLACK_BG}${1}${RESET}"
}

log () {
        echo "${YELLOW}${BLACK_BG}${1}${RESET}"
}

loginfo () {
        echo "${GREEN}${BLACK_BG}${1}${RESET}"
}

debuglog () {
    if [[ "${debug}" == "true" ]]; then
        echo "${CYAN}${BLACK_BG}${1}${RESET}"
    fi
}

if [[ "${auto}" == "auto" ]]; then
    loginfo "Running in Github Actions mode. Will not check creds"
elif [[ "${auto}" == "ssh" ]]; then
    loginfo "Running in ssh mode. Will set creds"
    export AWS_PROFILE="${envname}"
    export AWS_REGION="${region}"
    eval "$(aws configure export-credentials --profile ${AWS_PROFILE} --format env)"
else
    check_account=$(aws sts get-caller-identity | jq .Account -r)
    if [[ "$check_account" != "$AWS_ACCOUNT_ID" ]]; then
        logwarn "You are logged into the wrong AWS account. Please check your credentials and try again."
        exit 1
    fi
fi

config_message () {
    if [[ "${auto}" != "interactive" ]]; then
        check_ssh_shim=$(grep -q "id_rsa_${envname}_${reg}" ~/.ssh/config)
        if [[ $? -eq 0 ]]; then
            log "${envname}-${reg} SSH shim already in ~/.ssh/config"
            exit 0
        else
            log "Adding ${envname}-${reg} SSH shim to your ~/.ssh/config file."
            echo "# Auto added by create_ssh_key.sh" >> ~/.ssh/config
            echo "Host ${envname}-${reg}-*" >> ~/.ssh/config
            echo "    ProxyCommand sh -c \"~/.ssh/ssh_shim.sh '%r' '%h' '%p'\"" >> ~/.ssh/config
            echo "    IdentityFile ~/.ssh/id_rsa_${envname}_${reg}" >> ~/.ssh/config
            echo "" >> ~/.ssh/config
            exit 0
        fi
        exit 0
    else
        check_ssh_shim=$(grep -q "id_rsa_${envname}_${reg}" ~/.ssh/config)
        if [[ $? -eq 0 ]]; then
            log "${envname}-${reg} SSH shim already in ~/.ssh/config"
            exit 0
        fi
        log ""
        log "Please add the following to your ~/.ssh/config file:"
        log ""
        loginfo "# accepts instance-id for current region or instance-id,ew1 or instance-id,eu-west-1 etc"
        loginfo "Host ${envname}-${reg}-*"
        loginfo "    ProxyCommand sh -c \"~/.ssh/ssh_shim.sh '%r' '%h' '%p'\""
        loginfo "    IdentityFile ~/.ssh/id_rsa_${envname}_${reg}"
        log ""
    fi
}

setup_shim () {
    if [[ ! -L ~/.ssh/ssh_shim.sh ]]; then
        log "Setting up ssh-shim..."
        ln -s $(dirname $(realpath $0))/ssh_shim.sh ~/.ssh/ssh_shim.sh
        chmod +x ~/.ssh/ssh_shim.sh
    fi
    if [[ "${AWS_REGION}" == "" ]]; then
        log "AWS_REGION is not set. Setting to ${region}."
        export AWS_REGION=${region}
        logwarn "You should set AWS_REGION in your environment startup to avoid this warning. e.g. export AWS_REGION=${region}"
    fi
}

### Start script ###

sshkey_name="devops-sshkey"

if [[ "${auto}" != "auto" ]]; then
    # Create personal key for temporary use
    if [[ ! -f ~/.ssh/id_rsa_personal ]]; then
    log "Creating personal SSH key for shim usage on Ubuntu hosts '~/.ssh/id_rsa_personal'"
        ssh-keygen -t rsa -b 4096 -C "Personal key" -f ~/.ssh/id_rsa_personal -N "" 2>&1 > /dev/null
        #set permissions
        chmod 600 ~/.ssh/id_rsa_personal
    fi
fi

# Check if the sshkey already exists on local disk
sshkey_disk_exists=false

# Check if the sshkey already exists in env secret
sshkey_secret_exists=false

log "Checking for keys on disk and in AWS Secrets Manager..."

if [[ -f ~/.ssh/id_rsa_${envname}_${reg} ]]; then
    sshkey_disk_exists=true
    log "SSH key '~/.ssh/id_rsa_${envname}_${reg}' already exists."
    if [[ ! -f ~/.ssh/id_rsa_${envname}_${reg}.pub ]]; then
        log "However SSH public key '~/.ssh/id_rsa_${envname}_${reg}.pub' doesn't exist."
        log "Provide the public key too or delete the private key and rerun this script."
        exit 1
    fi
else
    log "SSH key '~/.ssh/id_rsa_${envname}_${reg}' does not exist."
fi

#check if aws secret exists
if aws secretsmanager describe-secret --secret-id "${envname}/${sshkey_name}" --region ${region}  2>&1 > /dev/null;
then
    debuglog "debug output: $?"
    sshkey_secret_exists=true
    log "SSH key '${sshkey_name}' already exists in AWS Secrets Manager in ${region}."
else
    log "SSH key '${sshkey_name}' does not exist in AWS Secrets Manager in ${region}."
fi

#if both exist then quit
if [[ "$sshkey_disk_exists" = true ]] && [[ "$sshkey_secret_exists" = true ]]; then
    log "SSH key '~/.ssh/id_rsa_${envname}_${reg}' and secret '${envname}/${sshkey_name}' in ${region} already exist. Exiting."
    setup_shim
    config_message
    exit 0
fi

#if neither exist then create both
if [[ "$sshkey_disk_exists" = false ]] && [[ "$sshkey_secret_exists" = false ]]; then
    log "SSH key '~/.ssh/id_rsa_${envname}_${reg}' and secret '${envname}/${sshkey_name}' in ${region} do not exist. Creating both."
    ssh-keygen -t rsa -b 4096 -C "${envname}_${reg}" -f ~/.ssh/id_rsa_${envname}_${reg} -N ""
    #set permissions
    chmod 600 ~/.ssh/id_rsa_${envname}_${reg}
    log "Creating both secrets in AWS Secrets Manager."
    aws secretsmanager create-secret --name "${envname}/${sshkey_name}" --secret-string file://~/.ssh/id_rsa_${envname}_${reg} --region ${region}
    aws secretsmanager create-secret --name "${envname}/${sshkey_name}.pub" --secret-string file://~/.ssh/id_rsa_${envname}_${reg}.pub --region ${region}
    setup_shim
    config_message
    exit 0
fi

#if only the secret exists then create the disk
if [[ "$sshkey_disk_exists" = false ]] && [[ "$sshkey_secret_exists" = true ]]; then
    log "SSH key '~/.ssh/id_rsa_${envname}_${reg}' does not exist. Creating."
    #copy secret to disk
    aws secretsmanager get-secret-value --secret-id "${envname}/${sshkey_name}" --region ${region} | jq -r '.SecretString' | cat > ~/.ssh/id_rsa_${envname}_${reg}
    aws secretsmanager get-secret-value --secret-id "${envname}/${sshkey_name}.pub" --region ${region} | jq -r '.SecretString' | cat > ~/.ssh/id_rsa_${envname}_${reg}.pub
    #set permissions
    chmod 600 ~/.ssh/id_rsa_${envname}_${reg}
    setup_shim
    config_message
    exit 0
fi

#if only the disk exists then create the secret
if [[ "$sshkey_disk_exists" = true ]] && [[ "$sshkey_secret_exists" = false ]]; then
    log "SSH key '${envname}/${sshkey_name}' does not exist in AWS Secrets Manager. Creating."
    log "Creating both secrets in AWS Secrets Manager."
    aws secretsmanager create-secret --name "${envname}/${sshkey_name}" --secret-string file://~/.ssh/id_rsa_${envname}_${reg} --region ${region}
    aws secretsmanager create-secret --name "${envname}/${sshkey_name}.pub" --secret-string file://~/.ssh/id_rsa_${envname}_${reg}.pub --region ${region}
    setup_shim
    config_message
    exit 0
fi
