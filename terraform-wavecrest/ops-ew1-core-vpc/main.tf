data "aws_caller_identity" "current" {}
data "aws_region" "current_region" {}

locals {
  config  = basename(path.cwd)
  account = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source = "./tf-connect-vpc"

  account        = local.account
  config         = local.config
  current_region = data.aws_region.current_region.name

  vpc_cidr                 = "10.154.4.0/23"
  single_nat_gateway       = true
  private_zone_name_suffix = "wavecrest.wc"

  wavecrest_create_cidr = "10.50.192.0/20"  # temporary change for arptel testing

  # eips
  reserved_slb_eips = 0
  reserved_rtp_eips = 0

  ############################
  # change the below defaults if needed
  ############################

  # public_zone_name = "${local.envname}.network.wavecrest.com" # Only needed if not this default
}

#### Outputs ####

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnets_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "database_subnets_cidr_blocks" {
  value = module.vpc.database_subnets_cidr_blocks
}

### Required terraform setup ###

terraform {
  required_version = ">= 1.6.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  alias  = "central"
  region = "eu-west-1"
}
