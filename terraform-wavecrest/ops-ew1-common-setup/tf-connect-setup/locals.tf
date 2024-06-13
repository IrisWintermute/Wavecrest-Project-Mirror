locals {
  tf_repo = basename(path.module)
  envname = split("-", var.config)[0]
  reg     = split("-", var.config)[1]
  colour  = split("-", var.config)[2]
  part    = split("-", var.config)[3]

  region = lookup({
    "ew1" = "eu-west-1"
    "ec1" = "eu-central-1"
    "uw1" = "us-west-1"
    "ue2" = "us-east-2"
    "as1" = "ap-south-1"
    "se1" = "sa-east-1"
  }, local.reg, "eu-west-1")

  environment = lookup({
    "dev" = "Develop"
    "tst" = "Test"
    "prd" = "Production"
    "ops" = "Operations"
  }, local.envname, "develop")

  common_tags = {
    CreatedBy      = "Terraform"
    Repo           = local.tf_repo
    Config         = var.config
    Colour         = local.colour
    Region         = local.region
    CostIdentifier = "Voice Network"
    map-migrated   = "mig8VPS82KVFO"
  }

  location = "${local.envname}-${local.reg}"

  enable_central = var.central_region == var.current_region ? true : false

  # kafka_key_id = local.enable_central ? aws_kms_key.kafka_msk_key[0].key_id : aws_kms_replica_key.kafka_replica[0].key_id

  normal_public_zone_name = "${local.envname}" == "prd" ? "network.wavecrest.com" : "${local.envname}.network.wavecrest.com"
  public_zone_name = "${var.public_zone_name}" == "" ? "${local.normal_public_zone_name}" : "${var.public_zone_name}"

  # lambda_names = local.enable_central ? {
  #   lambda_asge        = {allow_secrets_manager = true}
  #   lambda_call_events = {allow_msk_trigger = true}
  #   lambda_trigger     = {}
  #   lambda_events      = {allow_msk_trigger = true, allow_ec2_describe = true, allow_secrets_manager = true, allow_lifecycle_hooks = true, allow_route53 =true}
  #   lambda_events_api  = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_mysql_replication_monitor = {}
  #   lambda_monitor     = {allow_autoscale_health = true}
  #   lambda_ew1_blue_replicate  = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_ew1_green_replicate = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_se1_blue_replicate  = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_se1_green_replicate = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_ec1_blue_replicate  = {allow_msk_trigger = true, allow_secrets_manager = true}
  #   lambda_ec1_green_replicate = {allow_msk_trigger = true, allow_secrets_manager = true}

  # } : {}

  # #s3buckets
  slb_s3    = "${local.envname}-voice-slb"
  app_s3    = "${local.envname}-voice-app"
  rtp_s3    = "${local.envname}-voice-rtp"
  graf_s3   = "${local.envname}-voice-graf"
  obs_s3    = "${local.envname}-voice-obs"
  sipp_s3    = "${local.envname}-voice-sipp"
  lambda_s3 = "wavecrest-lambdas-${local.envname}"
  clickhouse_s3 = "${local.envname}-voice-clickhouse"

  # mysql_key_alias_suffix = "mysql-key"
  # clickhouse_key_alias_suffix = "clickhouse-key"
  # kafka_key_alias_suffix = "kafka-key"
  s3_key_alias_suffix = "s3-key"

  all_certificate_records_options = flatten([
    for cert in aws_acm_certificate.public_zone_cert : [
      for option in cert.domain_validation_options : option
    ]
  ])
}