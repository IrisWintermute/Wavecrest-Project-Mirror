locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    CreatedBy      = "Terraform"
    Repo           = "AI-Project"
    CostIdentifier = "Wavecrest AI Project"
    map-migrated   = "mig8VPS82KVFO"
  }

  split_cidr = cidrsubnets(var.vpc_cidr,3,3,3, 3,3,3, 5,5,5)

#   vpc_public_subnets = [local.split_cidr[0], local.split_cidr[1], local.split_cidr[2]]

  #256 IPs per AZ
  vpc_private_subnets = [local.split_cidr[3], local.split_cidr[4], local.split_cidr[5]]

  #30 IPs per AZ
  vpc_database_subnets = [local.split_cidr[6], local.split_cidr[7], local.split_cidr[8]]
}