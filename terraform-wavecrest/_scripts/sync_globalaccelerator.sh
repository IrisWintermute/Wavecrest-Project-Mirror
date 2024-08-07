#!/usr/bin/env bash

AWS_REGION=us-west-2
### Set variables ###
# if called from github actions
if [[ "${1}" != "" ]]; then
    envname=${1}
    short_region=${2}
    colour=${3}
    if [[ "${3}" == "" ]]; then
        echo "Not enough arguments. Usage: sync_globalaccelerator.sh <envname> <short_region> <colour>"
        exit 1
    fi
else
    # if called from the config directory
    directory=$(basename ${PWD})
    envname=$(cut -d'-' -f1 <<< $directory)
    short_region=$(cut -d'-' -f2 <<< $directory)
    colour=$(cut -d'-' -f3 <<< $directory)
fi


region=$(../_scripts/region.sh ${short_region})


accelerator_arn=$(aws globalaccelerator list-accelerators --query "Accelerators[?Name=='${envname}-ew1-core-slb']"|jq -r '.[0].AcceleratorArn')

contains() {
   key=${1}
   list=${2}

   for item in ${list}; do
       if [ "${key}" = "${item}" ]; then
          return 0
       fi
   done 
   return 1
}


echo "Global Accelerator ARN: ${accelerator_arn}"

get_slbs_for_region() {
    LB_LIST=$(aws elbv2 describe-load-balancers --region=${region} --query "LoadBalancers[].LoadBalancerArn" |jq -r '.[]')
    for lb in ${LB_LIST}; do
       tag_test=$(aws elbv2 describe-tags --region=${region} --resource-arns ${lb} |jq -r '.TagDescriptions[] |select(.Tags[] | (.Key=="Service" and .Value =="slb"))|select(.Tags[] | (.Key=="Network" and .Value =="public"))')
       if [ -n "${tag_test}" ]; then
           echo "${lb}"
       fi
    done
}

slb_list=$(get_slbs_for_region)
echo "Slb List=${slb_list}"

process_endpoint_groups() {
    listener_arn=${1}
    protocol=${2}
    port=${3}
    echo "Processing Listener: ${protocol}:${port}"
    ENDPOINT_GROUP_INFO=$(aws globalaccelerator list-endpoint-groups --listener-arn=${listener_arn})
    endpoint_list=$(echo ${ENDPOINT_GROUP_INFO} |jq -r ".EndpointGroups[] |select(.EndpointGroupRegion==\"${region}\") | .EndpointDescriptions[].EndpointId")
    endpoint_group_arn=$(echo ${ENDPOINT_GROUP_INFO} |jq -r ".EndpointGroups[] |select(.EndpointGroupRegion==\"${region}\") | .EndpointGroupArn")

   echo "endpoint group: ${endpoint_group_arn}"
   echo "endpoint list: ${endpoint_list}"

   for endpoint in ${endpoint_list}; do
      if ! contains "${endpoint}" "${slb_list}"; then
         echo "need to delete ${endpoint}"
         aws globalaccelerator remove-endpoints --endpoint-group-arn ${endpoint_group_arn} \
             --endpoint-identifiers "[{\"EndpointId\": \"${endpoint}\", \"ClientIPPreservationEnabled\": true}]"
      fi
   done

   for slb in ${slb_list}; do
      if ! contains "${slb}" "${endpoint_list}"; then
         echo "need to add ${slb}"
         aws globalaccelerator add-endpoints --endpoint-group-arn ${endpoint_group_arn} \
             --endpoint-configurations "[{\"EndpointId\": \"${slb}\", \"ClientIPPreservationEnabled\": true, \"Weight\": 0}]"
      fi
   done
}



LISTENER_INFO=$(aws globalaccelerator list-listeners --accelerator-arn=${accelerator_arn})


count=0
for listener_arn in $(echo "${LISTENER_INFO}" | jq -r '.Listeners[].ListenerArn'); do
    protocol=$(echo "${LISTENER_INFO}" | jq -r ".Listeners[${count}].Protocol")
    port=$(echo "${LISTENER_INFO}" | jq -r ".Listeners[${count}].PortRanges[0].FromPort")
    process_endpoint_groups ${listener_arn} ${protocol} ${port}
    count=$(($count + 1))
done
