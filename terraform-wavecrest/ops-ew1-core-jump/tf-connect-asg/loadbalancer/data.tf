data "aws_vpc" "colour_vpc" {
  tags = {
    Name = "${local.location}-vpc"
  }
}

data "aws_subnets" "nlb_public_subs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.colour_vpc.id]
  }
  tags = {
    Name = "*-public-*"
  }
}

data "aws_subnets" "nlb_private_subs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.colour_vpc.id]
  }
  tags = {
    Name = "*-private-*"
  }
}

data "aws_route53_zone" "private_zone" {
  name         = "${local.colour}.${local.reg}.${local.envname}.wavecrest.wc"
  private_zone = true
}

data "aws_route53_zone" "public_zone" {
  name = local.public_zone_name
}

data "aws_acm_certificate" "public" {
  domain   = "*.${local.public_zone_name}"
  statuses = ["ISSUED"]
}

data "dns_a_record_set" "ip_addresses" {
  count = length(var.loadbalance_rule) > 0 ? 1 : 0
  host  = aws_lb.asg-lb[0].dns_name
}