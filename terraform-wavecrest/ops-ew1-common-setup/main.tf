data "aws_caller_identity" "current" {}
data "aws_region" "current_region" {}

locals {
  config  = basename(path.cwd)
  account = data.aws_caller_identity.current.account_id
}

module "setup" {
  source = "./tf-connect-setup"

  account        = local.account
  config         = local.config
  current_region = data.aws_region.current_region.name

  ## defaults

  # envs to create separate secrets for mysql and kafka
  # env_colours       = ["blue", "green", "core"]

  # create needed secrets with random passwords
  # number_of_secrets = 7 #including paramstore values
  # vpn_secret        = { location = "vpn_key", secret_key = "preshared_key" }
  # api-ban_secret    = { location = "api-keys", secret_key = "api-ban" }
  # kafka_secret      = { location = "AmazonMSK_kafka", username = "admin", secret_key = "password" } # location has to begin "AmazonMSK_*"
  # mysql_secret    = { location = "mysql", secret_key = "password" }
  # clickhouse_secret= { location = "clickhouse", secret_key = "password" }
  # opsgenie_secret= { location = "opsgenie", api_key = "api_key" }
  # qryn_secret = { location = "qryn", secret_key = "password" }
  # create paramstore values with random passwords

  # create needed KMS keys
  # kafka_key_alias_suffix = "kafka-key"
  # clickhouse_key_alias_suffix = "clickhouse-key"

  # create public DNS zone
  # public_zone_name = "network.wavecrest.com"
  public_zone_cert = true

  ### SSH Keys ###

  # devops ssh keys
  # devops_sshkey_location = "devops-sshkey"          # location in secrets - public key is same but with ".pub" at the end
  # devops_sshkey_suffix     = "devops" # keypair name in AWS
}

### Outputs

# output "GenericProfile" {
#   value = module.vpc.GenericProfile
# }


### Required terraform setup ###

terraform {
  required_version = ">= 1.6.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.28.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  alias  = "central"
  region = "eu-west-1"
}
