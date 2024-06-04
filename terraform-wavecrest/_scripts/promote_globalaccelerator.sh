#!/usr/bin/env bash

### Set variables ###
# if called from github actions
if [[ "${1}" != "" ]]; then
    envname=${1}
    short_region=${2}
    colour=${3}
    if [[ "${3}" == "" ]]; then
        echo "Not enough arguments. Usage: promote_globalaccelerator.sh <envname> <short_region> <colour>"
        exit 1
    fi
else
    # if called from the config directory
    directory=$(basename ${PWD})
    envname=$(cut -d'-' -f1 <<< $directory)
    short_region=$(cut -d'-' -f2 <<< $directory)
    colour=$(cut -d'-' -f3 <<< $directory)
fi

core_reg="ew1" # core region
core_region="eu-west-1" # core region

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

trace () {
        echo "${YELLOW}${BLACK_BG}${1}${RESET}"
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
    echo "${output}"
}

invoke_api () {
    local method=${1}
    local path=${2}
    local body=${3}
    local output
    export jump_host="admin@${envname}-${core_reg}-core-jump"

    output=$(command_ssh "curl -s -X ${method} -H \"X-Voicenet-API-KEY: ${PROVISIONING_SECRET}\" -H \"Content-Type: application/json\" -H \"Accept: application/json\" -d \"${body}\" https://${PROVISIONING_LAMBDA}/api/v1/${path}")
    echo "${output}"
}

get_secret () {
    secret_name=${1}
    secret_key=${2}
    secret=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --query SecretString --output text --region ${core_region}| jq -r .${secret_key})
    echo ${secret}
}

region=$(../_scripts/region.sh ${short_region})


get_slbs_with_tags() {
   slb_info="[]"
    LB_LIST=$(aws elbv2 describe-load-balancers --region=${region} --query "LoadBalancers[].LoadBalancerArn" |jq -r '.[]')
    for lb in ${LB_LIST}; do
        tag_info=$(aws elbv2 describe-tags --region=${region} --resource-arns ${lb}|jq -r '.TagDescriptions[0]')
        slb_info=$(echo "${slb_info}"|jq ". += [${tag_info}]")
    done
    echo ${slb_info} 
}

get_slbs_for_region() {
    slb_info=${1}
    region_lb=$(echo "${slb_info}" |jq -r '.[] |select(.Tags[] | (.Key=="Service" and .Value =="slb"))|select(.Tags[] | (.Key=="Network" and .Value =="public"))|.ResourceArn')
    echo ${region_lb}
}

get_colours_for_region() {
    slb_info=${1}
    colours=$(echo "${slb_info}" |jq -r '.[] |select(.Tags[] | (.Key=="Service" and .Value =="slb"))|select(.Tags[] | (.Key=="Network" and .Value =="public"))|.Tags[]|select(.Key=="Colour")|.Value')
    echo "${colours}"
}

get_active_slb_for_region() {
    slb_info=${1}
    active_lb=$(echo "${slb_info}" |jq -r ".[] |select(.Tags[] | (.Key==\"Service\" and .Value ==\"slb\"))|select(.Tags[] | (.Key==\"Network\" and .Value ==\"public\"))|select(.Tags[] | (.Key==\"Colour\" and .Value ==\"${colour}\"))|.ResourceArn")
    echo "${active_lb}"
}

process_endpoint_groups() {
   listener_arn=${1}
   protocol=${2}
   port=${3}
   log "Updating listener: ${protocol}:${port}"
   ENDPOINT_GROUP_INFO=$(aws globalaccelerator list-endpoint-groups --region=us-west-2 --listener-arn=${listener_arn})
   endpoint_group_arn=$(echo ${ENDPOINT_GROUP_INFO} |jq -r ".EndpointGroups[] |select(.EndpointGroupRegion==\"${region}\") | .EndpointGroupArn")

   log "endpoint group: ${endpoint_group_arn}"

   updated_endpoints="[]"
   for slb in ${slb_list}; do
      if [ "${slb}" = "${active_slb}" ]; then
         updated_endpoints=$(echo "${updated_endpoints}"|jq ". += [{\"EndpointId\": \"${slb}\", \"Weight\": 128, \"ClientIPPreservationEnabled\": true}]")
       else
         updated_endpoints=$(echo "${updated_endpoints}"|jq ". += [{\"EndpointId\": \"${slb}\", \"Weight\": 0, \"ClientIPPreservationEnabled\": true}]")
      fi
   done
   output=$(aws globalaccelerator update-endpoint-group --region=us-west-2 --endpoint-group-arn=${endpoint_group_arn} --endpoint-configurations="${updated_endpoints}" --health-check-port=8080 --health-check-protocol=HTTP --health-check-path='/')
   trace "${output}"

}

accelerator_arn=$(aws globalaccelerator list-accelerators --region=us-west-2 --query "Accelerators[?Name=='${envname}-ew1-core-slb']"|jq -r '.[0].AcceleratorArn')

log  "Global Accelerator ARN: ${accelerator_arn}"
slb_info=$(get_slbs_with_tags)
slb_list=$(get_slbs_for_region "${slb_info}")
slb_colours=$(get_colours_for_region "${slb_info}")
active_slb=$(get_active_slb_for_region "${slb_info}")
log "Slb List=${slb_list}"
log "Active Slb=${active_slb}"
inactive_colours=$(echo "${slb_colours}"|grep -v ${colour})
log "Inactive Colours=${inactive_colours}"

export PROVISIONING_SECRET="$(get_secret ${envname}/provisioning_api api_key)"
if [[ "$envname" == "prd" ]]; then
    domain="network.wavecrest.com"
else
    domain="${envname}.network.wavecrest.com"
fi
export PROVISIONING_LAMBDA="provisioning-core-${core_reg}.${domain}"


LISTENER_INFO=$(aws globalaccelerator list-listeners --region=us-west-2 --accelerator-arn=${accelerator_arn})

count=0
for listener_arn in $(echo "${LISTENER_INFO}" | jq -r '.Listeners[].ListenerArn'); do
    protocol=$(echo "${LISTENER_INFO}" | jq -r ".Listeners[${count}].Protocol")
    port=$(echo "${LISTENER_INFO}" | jq -r ".Listeners[${count}].PortRanges[0].FromPort")
    process_endpoint_groups ${listener_arn} ${protocol} ${port}
    count=$(($count + 1))
done


log "Relasing traffic on inactive colours"
for inactive_colour in ${inactive_colours}; do
    log "Releasing traffic for ${inactive_colour}"
    output=$(invoke_api DELETE "slb_tcp_close" "{\\\"colour\\\":\\\"${inactive_colour}\\\", \\\"short_region\\\":\\\"${short_region}\\\"}")
    trace "${output}"
done

log "Promoting ${colour} to active"
output=$(invoke_api PUT "active_region" "{\\\"active_colour\\\":\\\"${colour}\\\", \\\"short_region\\\":\\\"${short_region}\\\", \\\"region_active\\\": true}")
trace "${output}"