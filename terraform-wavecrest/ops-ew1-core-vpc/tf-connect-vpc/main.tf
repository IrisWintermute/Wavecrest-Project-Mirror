resource "aws_eip" "nat_gateway" {
  count    = var.single_nat_gateway ? 1 : length(data.aws_availability_zones.available.names)
  instance = null
  tags = merge(tomap({
    Name = "${local.location}-private-nat"
  }), local.common_tags)
}

resource "aws_eip" "slb_eips" {
  count    = var.reserved_slb_eips
  instance = null
  tags = merge(tomap({
    Name = "${local.location}-slb-${count.index}"
  }), local.common_tags)
}

resource "aws_eip" "rtp_eips" {
  count    = var.reserved_rtp_eips
  instance = null
  tags = merge(tomap({
    Name = "${local.location}-rtp-${count.index}"
  }), local.common_tags)
}

resource "aws_eip" "sipp_carrier_eips" {
  count    = var.reserved_sipp_carrier_eips
  instance = null
  tags = merge(tomap({
    Name = "${local.location}-sippcarrier-${count.index}"
  }), local.common_tags)
}

resource "aws_eip" "sipp_customer_eips" {
  count    = var.reserved_sipp_customer_eips
  instance = null
  tags = merge(tomap({
    Name = "${local.location}-sippcustomer-${count.index}"
  }), local.common_tags)
}

resource "aws_route53_record" "slb" {
  count = var.reserved_slb_eips
  zone_id = data.aws_route53_zone.public_zone.zone_id
  name    = "${aws_eip.slb_eips[count.index].tags["Name"]}.${data.aws_route53_zone.public_zone.name}"
  type    = "A"
  records = [ aws_eip.slb_eips[count.index].public_ip ]
  ttl     = 60
}

resource "aws_route53_record" "srv_udp" {
  count = var.reserved_slb_eips > 0 ? 1 : 0
  zone_id    = data.aws_route53_zone.public_zone.zone_id
  name       = "_sip._udp.slb.${local.colour}.${local.reg}.${data.aws_route53_zone.public_zone.name}"
  type       = "SRV"
  ttl        = "300"
  records    = [
    for eip in aws_eip.slb_eips :
    "10 20 5060 ${eip.tags["Name"]}.${data.aws_route53_zone.public_zone.name}"
  ]
}

resource "aws_route53_record" "srv_tcp" {
  count = var.reserved_slb_eips > 0 ? 1 : 0
  zone_id    = data.aws_route53_zone.public_zone.zone_id
  name       = "_sip._tcp.slb.${local.colour}.${local.reg}.${data.aws_route53_zone.public_zone.name}"
  type       = "SRV"
  ttl        = "300"
  records    = [
    for eip in aws_eip.slb_eips :
    "10 20 5060 ${eip.tags["Name"]}.${data.aws_route53_zone.public_zone.name}"
  ]
}

module "connect-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name             = "${local.location}-vpc"
  cidr             = var.vpc_cidr
  azs              = local.azs
  private_subnets  = local.vpc_private_subnets
  public_subnets   = local.vpc_public_subnets
  database_subnets = local.vpc_database_subnets

  #create public ips if in public subnet
  map_public_ip_on_launch = true

  create_database_subnet_group       = false
  create_database_subnet_route_table = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway  = true
  single_nat_gateway  = var.single_nat_gateway
  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat_gateway.*.id

  manage_default_route_table = true
  default_route_table_tags   = { Name = "${local.location}-default" }

  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.location}-default-sg" }

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  flow_log_cloudwatch_log_group_retention_in_days = 7
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = local.common_tags
}

#create route53 private zone
resource "aws_route53_zone" "private_hosted_zone" {
  name          = "${local.colour}.${local.reg}.${local.envname}.${var.private_zone_name_suffix}"
  vpc {
    vpc_id = module.connect-vpc.vpc_id
  }
  tags = merge(tomap({
    Name = "${local.colour}.${local.reg}.${local.envname}.${var.private_zone_name_suffix}"
  }), local.common_tags)
}

# ## peer to central core vpc (if not central core)
# resource "aws_vpc_peering_connection" "peer_to_core" {
#   count         = local.enable_edge ? 1 : 0
#   peer_owner_id = var.account
#   peer_vpc_id   = data.aws_vpc.core_vpc[0].id
#   vpc_id        = module.connect-vpc.vpc_id
#   peer_region   = var.central_region
#   tags = merge(tomap({
#     Name = "${var.config} VPC Peering to Core" #must be same name as below
#   }), local.common_tags)
# }

# resource "aws_vpc_peering_connection_accepter" "accept_peering_to_core" {
#   count                     = local.enable_edge ? 1 : 0
#   provider                  = aws.central
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
#   auto_accept               = true

#   tags = merge(tomap({
#     Name = "${var.config} VPC Peering to Core" #must be same name as above
#   }), local.common_tags)
# }

# ## Add Routes between VPC to Central Core VPC
# resource "aws_route" "public_to_core_public" {
#   count                     = local.enable_edge ? 1 : 0
#   route_table_id            = module.connect-vpc.public_route_table_ids[0]
#   destination_cidr_block    = data.aws_vpc.core_vpc[0].cidr_block
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# resource "aws_route" "core_to_public" {
#   count                     = local.enable_edge ? 1 : 0
#   provider                  = aws.central
#   route_table_id            = data.aws_route_table.core_public[0].id
#   destination_cidr_block    = module.connect-vpc.vpc_cidr_block
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# resource "aws_route" "private_to_core_private" {
#   count                     = local.enable_edge ? 1 : 0
#   route_table_id            = module.connect-vpc.private_route_table_ids[0]
#   destination_cidr_block    = data.aws_vpc.core_vpc[0].cidr_block
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# resource "aws_route" "core_to_private" {
#   count                     = local.enable_edge ? 1 : 0
#   provider                  = aws.central
#   route_table_id            = data.aws_route_table.core_private[0].id
#   destination_cidr_block    = module.connect-vpc.vpc_cidr_block
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# ## Routes to Wavecrest Create via Central Core
# resource "aws_route" "public_to_wavecrest_create" {
#   count                  = local.enable_edge ? 1 : 0
#   route_table_id         = module.connect-vpc.public_route_table_ids[0]
#   destination_cidr_block = var.wavecrest_create_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# resource "aws_route" "private_to_wavecrest_create" {
#   count                  = local.enable_edge ? 1 : 0
#   route_table_id         = module.connect-vpc.private_route_table_ids[0]
#   destination_cidr_block = var.wavecrest_create_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.peer_to_core[0].id
# }

# add the VPCs Enabled to a parameter store entry
resource "aws_ssm_parameter" "vpcs_enabled" {
  name     = "/vpcs_enabled/${var.config}"
  type     = "String"
  value    = module.connect-vpc.vpc_cidr_block
  tags     = { Name = "${var.config} VPCs Enabled" }
  provider = aws.central
}

# add the VPCs ID to a parameter store entry
resource "aws_ssm_parameter" "vpcs_id" {
  name     = "/vpcs_id/${var.config}"
  type     = "String"
  value    = module.connect-vpc.vpc_id
  tags     = { Name = "${var.config} VPC id" }
  provider = aws.central
}

## add the NATs Enabled to a parameter store entry
resource "aws_ssm_parameter" "nats_enabled" {
  name     = "/nats_enabled/${var.config}"
  type     = "String"
  value    = join(", ", local.nat_public_cidr)
  tags     = { Name = "${var.config} NATs Enabled" }
  provider = aws.central
}

# add the VPCs Private Subnets to a parameter store entry
resource "aws_ssm_parameter" "vpcs_private_subnets" {
  name     = "/vpcs_private_ids/${var.config}"
  type     = "String"
  value    = join(",", module.connect-vpc.private_subnets)
  tags     = { Name = "${var.config} VPCs Private Subnets" }
  provider = aws.central
}

provider "aws" {
  alias  = "central"
  region = "eu-west-1"
}

output "vpc_cidr_block" {
  value = module.connect-vpc.vpc_cidr_block
}

output "public_subnets_cidr_blocks" {
  value = module.connect-vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  value = module.connect-vpc.private_subnets_cidr_blocks
}

output "database_subnets_cidr_blocks" {
  value = module.connect-vpc.database_subnets_cidr_blocks
}