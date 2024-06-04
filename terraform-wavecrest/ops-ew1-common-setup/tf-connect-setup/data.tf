data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_secretsmanager_secret" "ssh_key" {
  name = "${local.envname}/${var.devops_sshkey_location}.pub"
}

data "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id = data.aws_secretsmanager_secret.ssh_key.id
}

# data "aws_iam_policy" "AWSLambdaVPCAccessExecutionRole" {
#   name = "AWSLambdaVPCAccessExecutionRole"
# }

# data "aws_iam_policy" "AWSLambdaMSKExecutionRole" {
#   name = "AWSLambdaMSKExecutionRole"
# }

# data "aws_kms_key" "kafka_key" {
#   count = local.enable_central ? 0 : 1
#   provider = aws.central
#   key_id = "alias/${local.envname}-${local.kafka_key_alias_suffix}"
# }

# data "aws_kms_key" "mysql_key" {
#   count = local.enable_central ? 0 : 1
#   provider = aws.central
#   key_id = "alias/${local.envname}-${local.mysql_key_alias_suffix}"
# }

# data "aws_kms_key" "clickhouse_key" {
#   count = local.enable_central ? 0 : 1
#   provider = aws.central
#   key_id = "alias/${local.envname}-${local.clickhouse_key_alias_suffix}"
# }

data "aws_kms_key" "s3_key" {
  count = local.enable_central ? 0 : 1
  provider = aws.central
  key_id = "alias/${local.envname}-${local.s3_key_alias_suffix}"
}