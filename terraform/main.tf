resource "aws_vpc" "ai-project-vpc" {
 cidr_block = var.vpc_cidr

 tags = merge(tomap({
   Name = "AI Project VPC"
 }), local.common_tags)
}

 resource "aws_subnet" "public_subnets" {
  count             = length(local.vpc_public_subnets)
  vpc_id            = aws_vpc.ai-project-vpc.id
  cidr_block        = element(local.vpc_public_subnets, count.index)
  availability_zone = element(local.azs, count.index)

  tags = {
   Name = "Public Subnet ${count.index + 1}"
  }
 }

resource "aws_subnet" "private_subnets" {
 count             = length(local.vpc_private_subnets)
 vpc_id            = aws_vpc.ai-project-vpc.id
 cidr_block        = element(local.vpc_private_subnets, count.index)
 availability_zone = element(local.azs, count.index)

 tags = merge(tomap({
   Name = "Private Subnet ${count.index + 1}"
 }), local.common_tags)
}

resource "aws_subnet" "db_subnets" {
 count             = length(local.vpc_database_subnets)
 vpc_id            = aws_vpc.ai-project-vpc.id
 cidr_block        = element(local.vpc_database_subnets, count.index)
 availability_zone = element(local.azs, count.index)

 tags = merge(tomap({
   Name = "Database Subnet ${count.index + 1}"
 }), local.common_tags)
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
