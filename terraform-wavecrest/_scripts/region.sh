#!/usr/bin/env bash
#lookup region from shortcode

short_region=${1:-ew1}
declare -A REGION_LOOKUP
REGION_LOOKUP["ew1"]="eu-west-1"
REGION_LOOKUP["ec1"]="eu-central-1"
REGION_LOOKUP["se1"]="sa-east-1"
# REGION_LOOKUP["uw1"]="us-west-1"
# REGION_LOOKUP["ue2"]="us-east-2"
# REGION_LOOKUP["as1"]="ap-south-1"
region=${REGION_LOOKUP[${short_region}]}

echo $region