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
export sql_scripts_location="$(realpath ../../../tf-connect-${part}/scripts)"

export mysql_admin="admin"
export mysql_viewer="viewer"
export mysql_replica="${short_region}_${colour}_replication"

export CORE_MYSQL_HOST="$(terraform output mysql_core_endpoint | sed 's/"//g')"

#get core db region from host
export CORE_MYSQL_REGION=$(echo ${CORE_MYSQL_HOST} | cut -d'.' -f3)
export CORE_MYSQL_PASSWORD="$(get_secret ${envname}/mysql-core ${mysql_admin} ${CORE_MYSQL_REGION})"

# specific vars
if [[ "${part}" == "mysql_edge" ]]; then
    #get binlog name and position from edge
    export edge_instance_id="$(terraform output mysql_edge_aws_rds_cluster_instance_identifier | sed 's/"//g')"
    export event="$(aws rds describe-events --source-identifier ${edge_instance_id} --source-type db-instance --duration 7200 --region ${region}| grep 'mysql-bin-changelog')"
    #Binlog position: mysql-bin-changelog.000002 120
    if [[ "${event}" =~ before\ reset\ is\ (mysql-bin-changelog.*)\ (.*),\ master ]]; then
        export CORE_BINLOG_NAME="${BASH_REMATCH[1]}"
        export CORE_BINLOG_POSITION="${BASH_REMATCH[2]}"
    elif [[ "${event}" =~ crash\ recovery\ is\ (.*)\ (.*)\" ]]; then
        export CORE_BINLOG_NAME="${BASH_REMATCH[1]}"
        export CORE_BINLOG_POSITION="${BASH_REMATCH[2]}"
    else
        log "ERROR: Could not get binlog position from edge instance events. Events found:"
        aws rds describe-events --source-identifier ${edge_instance_id} --source-type db-instance --duration 3600 --region ${region}
        log "---Exiting"
        exit 0
    fi

    export EDGE_MYSQL_HOST=$(terraform output mysql_edge_endpoint| sed 's/"//g')

    export EDGE_MYSQL_PASSWORD="$(get_secret ${envname}/mysql-${colour} ${mysql_admin})"
    export EDGE_VIEWER_PASSWORD="$(get_secret ${envname}/mysql-viewer-${colour} ${mysql_viewer})"
    export EDGE_REPLICA_PASSWORD="$(get_secret ${envname}/mysql-${colour} ${mysql_replica})"

    export provision_var_string="EDGE_MYSQL_USER=${mysql_admin} EDGE_MYSQL_PASSWORD=${EDGE_MYSQL_PASSWORD} CORE_MYSQL_USER=${mysql_admin} CORE_MYSQL_PASSWORD=${CORE_MYSQL_PASSWORD} EDGE_MYSQL_HOST=${EDGE_MYSQL_HOST} CORE_MYSQL_HOST=${CORE_MYSQL_HOST} EDGE_VIEWER_USER=${mysql_viewer} EDGE_VIEWER_PASSWORD=${EDGE_VIEWER_PASSWORD} EDGE_REPLICA_USER=${mysql_replica} EDGE_REPLICA_PASSWORD=${EDGE_REPLICA_PASSWORD} CORE_BINLOG_NAME=${CORE_BINLOG_NAME} CORE_BINLOG_POSITION=${CORE_BINLOG_POSITION}"
else
    export provision_var_string="MYSQL_HOST=${CORE_MYSQL_HOST} MYSQL_PASSWORD=${CORE_MYSQL_PASSWORD} MYSQL_USER=${mysql_admin}"
fi

## set up provisioner
export jump_host="admin@${envname}-${short_region}-${colour}-jump"
log "Setting up provisioner on jump host ${jump_host}"

command_ssh 'sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get install -qq --assume-yes mariadb-client rsync dnsutils'


if [[ "${part}" == "mysql_edge" ]]; then
    log "Checking if already replicating and if so then stop"
    fail_ok=true
    command_ssh "mysql -h ${EDGE_MYSQL_HOST} -u ${mysql_admin} -p${EDGE_MYSQL_PASSWORD} -e 'SHOW REPLICA STATUS\G' | grep 'Replica_IO_Running: Yes'"
    fail_ok=false
# else
#     log "Checking if already provisioned and if so then stop"
#     fail_ok=true
#     command_ssh "mysql -h ${CORE_MYSQL_HOST} -u ${mysql_admin} -p${CORE_MYSQL_PASSWORD} -e 'SHOW TABLE STATUS FROM voicenet;' | grep 'slb_kamailio_address'"
#     fail_ok=false
fi

log "Set up temp directory for scripts"
command_ssh 'if [[ -d /tmp/sql ]]; then rm -rf /tmp/sql; else echo "No existing /tmp/sql directory"; fi'
command_ssh 'mkdir -p /tmp/sql'

log "RSYNC: rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${sql_scripts_location}/ ${jump_host}:/tmp/sql/"
rsync -av -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' ${sql_scripts_location}/ ${jump_host}:/tmp/sql/

log "Running provisioner on jump host ${jump_host}"

command_ssh "cd /tmp/sql && ${provision_var_string} ./provision.sh > /tmp/sql/provision.log 2>&1"

if [[ "${debug}" == "true" ]]; then
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${jump_host} -t "cat /tmp/sql/provision.log"
fi

log "Finished"
