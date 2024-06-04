locals {
  envname = split("-", var.config)[0]
  reg     = split("-", var.config)[1]
  colour  = split("-", var.config)[2]
  part    = split("-", var.config)[3]

  location = "${local.envname}-${local.reg}-${local.colour}"
  tf_repo  = basename(path.module)

  region = lookup({
    "ew1" = "eu-west-1"
    "ec1" = "eu-central-1"
    "uw1" = "us-west-1"
    "ue2" = "us-east-2"
    "as1" = "ap-south-1"
    "se1" = "sa-east-1"
  }, local.reg, "eu-west-1")

  sub      = length(var.loadbalance_rule) > 0 ? var.loadbalance_rule[0].loadbalancer_subnet == "public" ? "pub" : "priv" : ""
  short_lb = length(var.loadbalance_rule) > 0 ? var.loadbalance_rule[0].protocol == "HTTP" ? "a" : "n" : ""
  common_tags = {
    CreatedBy      = "Terraform"
    Repo           = local.tf_repo
    Config         = var.config
    Colour         = local.colour
    Region         = local.region
    CostIdentifier = "Voice Network"
    map-migrated   = "mig8VPS82KVFO"
    Service        = local.part
  }
  normal_public_zone_name = "${local.envname}" == "prd" ? "network.wavecrest.com" : "${local.envname}.network.wavecrest.com"
  public_zone_name = "${var.public_zone_name}" == "" ? "${local.normal_public_zone_name}" : "${var.public_zone_name}"

  name = "${local.reg}-${local.colour}-${local.part}-${local.sub}-${local.short_lb}"
}