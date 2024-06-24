data "aws_availability_zones" "available" {
  state = "available"
}

### VPC

#find eips by filtering on name
data "aws_eips" "reserved_eips" {
  count = var.use_eips ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${local.location}-${local.servertype}-*"]
  }
}

data "aws_eip" "reserved_eips_info" {
  count = var.use_eips ? length(data.aws_eips.reserved_eips[0].allocation_ids) : 0
  id    = data.aws_eips.reserved_eips[0].allocation_ids[count.index]
}

data "aws_vpc" "colour_vpc" {
  tags = {
    Name = "${local.location}-vpc"
  }
}

data "aws_subnets" "location_subs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.colour_vpc.id]
  }
  tags = {
    Name = "*-${var.location_subnet}-*"
  }
}

data "aws_ec2_instance_types" "instance_type" {
  filter {
    name   = "instance-type"
    values = ["${var.instance_family}*"]
  }

  filter {
    name   = "current-generation"
    values = ["true"]
  }
  filter {
    name = "processor-info.supported-architecture"
    values = [var.instance_architecture]
  }
  filter {
    name = "vcpu-info.default-vcpus"
    values = [var.instance_num_cpus]
  }
  filter {
    name = "burstable-performance-supported"
    values = [var.instance_burstable]
  }
  filter {
    name = "memory-info.size-in-mib"
    values = [var.instance_memory]
  }
}

data "aws_ec2_spot_price" "instance_price" {
  for_each = toset(data.aws_ec2_instance_types.instance_type.instance_types)
  instance_type = each.value
  availability_zone = data.aws_availability_zones.available.names[0]
  filter {
    name   = "product-description"
    values = ["Linux/UNIX"]
  }
}

#find ami id by filtering on name
data "aws_ami" "ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami}"]
  }
}

### Wavecrest Specific


## DB

data "aws_secretsmanager_secret" "mysql_password" {
  count = var.enable_db_envs ? 1 : 0
  name  = "${local.envname}/mysql-viewer-${local.colour}"
}

data "aws_secretsmanager_secret_version" "mysql_password" {
  count     = var.enable_db_envs ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.mysql_password[0].arn
}

data "aws_rds_cluster" "mysql" {
  count              = var.enable_db_envs ? 1 : 0
  cluster_identifier = "${local.reg}-${local.colour}-mysql-edge"
}

## Kafka
data "aws_secretsmanager_secret" "kafka_password" {
  count = var.enable_kafka_envs ? 1 : 0
  name  = "AmazonMSK_kafka-${local.envname}-${local.colour}"
}

data "aws_secretsmanager_secret_version" "kafka_password" {
  count     = var.enable_kafka_envs ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.kafka_password[0].arn
}

data "aws_msk_cluster" "kafka_cluster" {
  count        = var.enable_kafka_envs ? 1 : 0
  cluster_name = "${local.location}-kafka"
}

## Qryn
data "aws_secretsmanager_secret" "qryn_password" {
  count = var.enable_qryn_envs ? 1 : 0
  name  = "${local.envname}/qryn"
}

data "aws_secretsmanager_secret_version" "qryn_password" {
  count     = var.enable_qryn_envs ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.qryn_password[0].arn
}

## Clickhouse
# data "aws_secretsmanager_secret" "clickhouse_secret" {
#   provider = aws.central
#   name     = "${local.envname}/clickhouse"
# }

# data "aws_secretsmanager_secret_version" "clickhouse_secret_version" {
#   provider  = aws.central
#   secret_id = data.aws_secretsmanager_secret.clickhouse_secret.arn
# }

## Opsgenie
# data "aws_secretsmanager_secret" "opsgenie_secret" {
#   provider = aws.central
#   name     = "${local.envname}/opsgenie"
# }

# data "aws_secretsmanager_secret_version" "opsgenie_secret_version" {
#   provider  = aws.central
#   secret_id = data.aws_secretsmanager_secret.opsgenie_secret.arn
# }

## grafana oauth
# data "aws_secretsmanager_secret" "grafana_oauth_secret" {
#   provider = aws.central
#   name     = "${local.envname}/grafana"
# }

# data "aws_secretsmanager_secret_version" "grafana_oauth_secret" {
#   provider  = aws.central
#   secret_id = data.aws_secretsmanager_secret.grafana_oauth_secret.arn
# }

## Api ban
# data "aws_secretsmanager_secret" "api_ban_secret" {
#   provider = aws.central
#   name     = "${local.envname}/apiban"
# }

# data "aws_secretsmanager_secret_version" "api_ban_secret_version" {
#   provider  = aws.central
#   secret_id = data.aws_secretsmanager_secret.api_ban_secret.arn
# }

# data "aws_secretsmanager_secret" "app_server_secret" {
#   count = var.enable_app_server_envs ? 1 : 0
#   name  = "${local.envname}/app_auth-${local.colour}"
# }

# data "aws_secretsmanager_secret_version" "app_server_secret" {
#   count     = var.enable_app_server_envs ? 1 : 0
#   secret_id = data.aws_secretsmanager_secret.app_server_secret[0].arn
# }

data "aws_route53_zone" "private_zone" {
  name         = "${local.colour}.${local.reg}.${local.envname}.wavecrest.wc"
  private_zone = true
}

data "aws_route53_zone" "public_zone" {
  name = local.public_zone_name
}

# add the VPC CIDRs from a parameter store entry
data "aws_ssm_parameters_by_path" "all_vpc_cidrs" {
  path     = "/vpcs_enabled/"
  provider = aws.central
}

# data "aws_globalaccelerator_accelerator" "anycast" {
#   name = "${local.envname}-${local.central_reg}-core-slb"
# }