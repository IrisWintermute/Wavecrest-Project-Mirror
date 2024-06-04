locals {
  azs     = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    CreatedBy      = "Terraform"
    Repo           = local.tf_repo
    Config         = var.config
    Colour         = local.colour
    Region         = local.region
    CostIdentifier = "Voice Network"
    map-migrated   = "mig8VPS82KVFO"
  }

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

  location = "${local.envname}-${local.reg}-${local.colour}"

  enable_central = var.central_region == var.current_region ? true : false
  enable_edge    = "${local.location}" != "${local.envname}-${local.reg}-core" ? true : false

  central_region = "ew1"

  split_cidr = cidrsubnets(var.vpc_cidr,3,3,3, 3,3,3, 5,5,5)
  # 3 = /26 network - 62 IPs per AZ
  # 5 = /28 network - 14 IPs per AZ

  vpc_public_subnets = [local.split_cidr[0], local.split_cidr[1], local.split_cidr[2]]

  #256 IPs per AZ
  vpc_private_subnets = [local.split_cidr[3], local.split_cidr[4], local.split_cidr[5]]

  #30 IPs per AZ
  vpc_database_subnets = [local.split_cidr[6], local.split_cidr[7], local.split_cidr[8]]

  normal_public_zone_name = "${local.envname}" == "prd" ? "network.wavecrest.com" : "${local.envname}.network.wavecrest.com"
  public_zone_name = "${var.public_zone_name}" == "" ? "${local.normal_public_zone_name}" : "${var.public_zone_name}"

  nat_public_cidr = [for ip in aws_eip.nat_gateway.*.public_ip : "${ip}/32"]
}
