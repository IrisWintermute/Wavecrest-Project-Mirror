data "aws_availability_zones" "available" {}

data "aws_route53_zone" "public_zone" {
  name = "${local.public_zone_name}"
}

data "aws_vpc" "core_vpc" {
  count    = local.enable_edge ? 1 : 0
  provider = aws.central
  tags = {
    Name = "${local.envname}-${local.central_region}-core-vpc"
  }
}

data "aws_route_table" "core_public" {
  count    = local.enable_edge ? 1 : 0
  provider = aws.central
  vpc_id   = data.aws_vpc.core_vpc[0].id
  filter {
    name   = "tag:Name"
    values = ["${local.envname}-${local.central_region}-core-vpc-public"]
  }
}

data "aws_route_table" "core_private" {
  count    = local.enable_edge ? 1 : 0
  provider = aws.central
  vpc_id   = data.aws_vpc.core_vpc[0].id
  filter {
    name   = "tag:Name"
    values = ["${local.envname}-${local.central_region}-core-vpc-private"]
  }
}