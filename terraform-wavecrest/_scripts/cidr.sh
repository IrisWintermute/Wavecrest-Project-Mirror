#!/usr/bin/env bash
#lookup cidr from env-reg

envname=${1:-dev}
short_region=${2:-ew1}
colour=${3:-blue}
declare -A CIDR_LOOKUP
#dev
CIDR_LOOKUP["dev-ew1-blue"]="10.151.0.0/23"
CIDR_LOOKUP["dev-ew1-green"]="10.151.2.0/23"
CIDR_LOOKUP["dev-ew1-core"]="10.151.4.0/23"
CIDR_LOOKUP["dev-ec1-blue"]="10.151.8.0/23"
CIDR_LOOKUP["dev-ec1-green"]="10.151.10.0/23"
CIDR_LOOKUP["dev-se1-blue"]="10.151.16.0/23"
CIDR_LOOKUP["dev-se1-green"]="10.151.18.0/23"

#tst
CIDR_LOOKUP["tst-ew1-blue"]="10.152.0.0/23"
CIDR_LOOKUP["tst-ew1-green"]="10.152.2.0/23"
CIDR_LOOKUP["tst-ew1-core"]="10.152.4.0/23"
CIDR_LOOKUP["tst-ec1-blue"]="10.152.8.0/23"
CIDR_LOOKUP["tst-ec1-green"]="10.152.10.0/23"
CIDR_LOOKUP["tst-se1-blue"]="10.152.16.0/23"
CIDR_LOOKUP["tst-se1-green"]="10.152.18.0/23"

#prd
CIDR_LOOKUP["prd-ew1-blue"]="10.153.0.0/23"
CIDR_LOOKUP["prd-ew1-green"]="10.153.2.0/23"
CIDR_LOOKUP["prd-ew1-core"]="10.153.4.0/23"
CIDR_LOOKUP["prd-ec1-blue"]="10.153.16.0/23"
CIDR_LOOKUP["prd-ec1-green"]="10.153.18.0/23"
CIDR_LOOKUP["prd-se1-blue"]="10.153.8.0/23"
CIDR_LOOKUP["prd-se1-green"]="10.153.10.0/23"

cidr=${CIDR_LOOKUP["${envname}-${short_region}-${colour}"]}
echo "${cidr}"