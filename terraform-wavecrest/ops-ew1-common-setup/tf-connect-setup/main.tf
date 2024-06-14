# add route 53 public zone
resource "aws_route53_zone" "public_zone" {
  count = local.enable_central ? 1 : 0
  name    = "${local.public_zone_name}"
  comment = "Public zone for ${local.envname}"

  tags = merge(tomap({
    Name = "${local.environment} Public Zone"
  }), local.common_tags)
}

resource "aws_acm_certificate" "public_zone_cert" {
  count             = var.public_zone_cert ? 1 : 0
  domain_name       = "*.${local.public_zone_name}"
  validation_method = "DNS"

  tags = merge(tomap({
    Name = "${local.environment} Public Zone Cert"
  }), local.common_tags)
}

resource "aws_route53_record" "acm_validation" {
  count           = local.enable_central ? length(local.all_certificate_records_options) : 0
  allow_overwrite = true
  name            = local.all_certificate_records_options[count.index].resource_record_name
  records         = [local.all_certificate_records_options[count.index].resource_record_value]
  ttl             = 60
  type            = local.all_certificate_records_options[count.index].resource_record_type
  zone_id         = aws_route53_zone.public_zone[0].zone_id
}

# ## SECRETS MANAGER ##
# resource "random_password" "starting_password" {
#   count            = var.number_of_secrets
#   length           = 16
#   special          = true
#   override_special = "._" #due to vpn key
# }

# # VPN key (can only contain alphanumeric, period and underscore characters)
# resource "aws_secretsmanager_secret" "vpn_secret" {
#   name = "${local.envname}/${var.vpn_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} VPN Preshared Key"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "vpn_secret_values" {
#   secret_id = aws_secretsmanager_secret.vpn_secret.id
#   secret_string = jsonencode({
#     "${var.vpn_secret["secret_key"]}" = "${random_password.starting_password[0].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "api-ban_secret" {
#   name = "${local.envname}/${var.api-ban_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} API BAN Password"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "api-ban_secret_values" {
#   secret_id = aws_secretsmanager_secret.api-ban_secret.id

#   secret_string = jsonencode({
#     "${var.api-ban_secret["secret_key"]}" = "${random_password.starting_password[1].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "opsgenie_secret" {
#   name = "${local.envname}/${var.opsgenie_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} Opsgenie API Key"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "opsgenie_secret_values" {
#   secret_id = aws_secretsmanager_secret.opsgenie_secret.id

#   secret_string = jsonencode({
#     "${var.opsgenie_secret["secret_key"]}" = "${random_password.starting_password[7].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "grafana_oauth_secret" {
#   name = "${local.envname}/${var.grafana_oauth_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} Grafana Oauth Key"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "grafana_oauth_secret" {
#   secret_id = aws_secretsmanager_secret.grafana_oauth_secret.id

#   secret_string = jsonencode({
#     "${var.grafana_oauth_secret["tenant_id"]}" = "", # must be manually set to correct value
#     "${var.grafana_oauth_secret["client_id"]}" = "", # must be manually set to correct value
#     "${var.grafana_oauth_secret["client_secret"]}" = "", # must be manually set to correct value

#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }


# #create kafka secret for all 3 colours, core, blue and green

# resource "aws_secretsmanager_secret" "kafka_secret" {
#   depends_on = [ aws_kms_key.kafka_msk_key[0] , aws_kms_replica_key.kafka_replica[0] ]
#   for_each = { for color in var.env_colours : color => color }
#   name     = "${var.kafka_secret["location"]}-${local.envname}-${each.value}"
#   # location has to begin "AmazonMSK_*"
#   # default to "AmazonMSK_kafka"
#   kms_key_id = local.kafka_key_id
#   tags = merge(tomap({
#     Name = "${local.location}-${each.value} Kafka Password"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "kafka_secret_values" {
#   for_each  = { for color in var.env_colours : color => color }
#   secret_id = aws_secretsmanager_secret.kafka_secret[each.value].id

#   secret_string = jsonencode({
#     "username"                          = "${var.kafka_secret["username"]}",
#     "${var.kafka_secret["secret_key"]}" = "${random_password.starting_password[2].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "mysql_viewer_secret" {
#   for_each = { for color in var.env_colours : color => color }
#   name     = "${local.envname}/${var.mysql_secret["location"]}-viewer-${each.value}"

#   tags = merge(tomap({
#     Name = "${local.location}-${each.value} MySQL Password"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "mysql_viewer_secret_values" {
#   for_each  = { for color in var.env_colours : color => color }
#   secret_id = aws_secretsmanager_secret.mysql_viewer_secret[each.value].id

#   secret_string = jsonencode({
#     "viewer"      = "${random_password.starting_password[3].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "mysql_secret" {
#   for_each = { for color in var.env_colours : color => color }
#   name     = "${local.envname}/${var.mysql_secret["location"]}-${each.value}"

#   tags = merge(tomap({
#     Name = "${local.location}-${each.value} MySQL Password"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "mysql_secret_values" {
#   for_each  = { for color in var.env_colours : color => color }
#   secret_id = aws_secretsmanager_secret.mysql_secret[each.value].id

#   secret_string = jsonencode({
#     "admin"       = "${random_password.starting_password[4].result}",
#     "${local.reg}_${each.value}_replication" = "${random_password.starting_password[5].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "clickhouse_secret" {
#   name = "${local.envname}/${var.clickhouse_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} Clickhouse secret"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "clickhouse_secret_values" {
#   secret_id = aws_secretsmanager_secret.clickhouse_secret.id
#   secret_string = jsonencode({
#     "${var.clickhouse_secret["secret_key"]}" = "${random_password.starting_password[6].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "qryn_secret" {
#   name = "${local.envname}/${var.qryn_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} qryn secret"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "qryn_secret_values" {
#   secret_id = aws_secretsmanager_secret.qryn_secret.id
#   secret_string = jsonencode({
#     "${var.qryn_secret["secret_key"]}" = "${random_password.starting_password[8].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "provisioning_api_secret" {
#   name = "${local.envname}/${var.provisioning_api_secret["location"]}"

#   tags = merge(tomap({
#     Name = "${local.environment} provisioning api secret"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "provisioning_api_secret_values" {
#   secret_id = aws_secretsmanager_secret.provisioning_api_secret.id
#   secret_string = jsonencode({
#     "${var.provisioning_api_secret["secret_key"]}" = "${random_password.starting_password[8].result}"
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# resource "aws_secretsmanager_secret" "app_auth_secret" {
#   for_each = { for color in var.env_colours : color => color if color != "core" }
#   name     = "${local.envname}/${var.app_auth_secret["location"]}-${each.value}"

#   tags = merge(tomap({
#     Name = "${local.location}-${each.value} Kamailio App Server Auth Secret"
#   }), local.common_tags)
# }

# resource "aws_secretsmanager_secret_version" "app_auth_secret" {
#   for_each  = { for color in var.env_colours : color => color if color != "core" }
#   secret_id = aws_secretsmanager_secret.app_auth_secret[each.value].id

#   secret_string = jsonencode({
#     "secret"       = "${random_password.starting_password[9].result}",
#   })
#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

### KMS Keys ###

# # Create a KMS Key for MSK Encryption
# resource "aws_kms_key" "kafka_msk_key" {
#   count = local.enable_central ? 1 : 0
#   description             = "KMS key for Kafka MSK encryption"
#   deletion_window_in_days = 7
#   multi_region            = true

#   tags = merge(tomap({
#     Name = "${local.environment} Kafka MSK Key"
#   }), local.common_tags)
# }

# resource "aws_kms_alias" "kafka_key" {
#   count = local.enable_central ? 1 : 0
#   name          = "alias/${local.envname}-${local.kafka_key_alias_suffix}"
#   target_key_id = aws_kms_key.kafka_msk_key[0].key_id
# }

# resource "aws_kms_replica_key" "kafka_replica" {
#   count = local.enable_central ? 0 : 1
#   description             = "Replica key for kafka MSK encryption"
#   deletion_window_in_days = 7
#   primary_key_arn         = data.aws_kms_key.kafka_key[0].arn
# }

# resource "aws_kms_alias" "kafka_replica" {
#   count = local.enable_central ? 0 : 1
#   name          = "alias/${local.envname}-${local.kafka_key_alias_suffix}"
#   target_key_id = aws_kms_replica_key.kafka_replica[0].key_id
# }

# # Create a KMS Key for Clickhouse Encryption
# resource "aws_kms_key" "clickhouse_key" {
#   count = local.enable_central ? 1 : 0
#   description             = "KMS key for Clickhouse Encryption"
#   deletion_window_in_days = 7
#   multi_region            = true

#   tags = merge(tomap({
#     Name = "${local.environment} Clickhouse Key"
#   }), local.common_tags)
# }

# resource "aws_kms_alias" "clickhouse_key" {
#   count = local.enable_central ? 1 : 0
#   name          = "alias/${local.envname}-${local.clickhouse_key_alias_suffix}"
#   target_key_id = aws_kms_key.clickhouse_key[0].key_id
# }

# # Replicas
# resource "aws_kms_replica_key" "clickhouse_replica" {
#   count = local.enable_central ? 0 : 1
#   description             = "Replica key for clickhouse MSK encryption"
#   deletion_window_in_days = 7
#   primary_key_arn         = data.aws_kms_key.clickhouse_key[0].arn
# }

# resource "aws_kms_alias" "clickhouse_replica" {
#   count = local.enable_central ? 0 : 1
#   name          = "alias/${local.envname}-${local.clickhouse_key_alias_suffix}"
#   target_key_id = aws_kms_replica_key.clickhouse_replica[0].key_id
# }

# # Create a key for mysql encryption
# resource "aws_kms_key" "mysql_key" {
#   count = local.enable_central ? 1 : 0
#   description             = "KMS key for MySQL Encryption"
#   deletion_window_in_days = 7
#   multi_region            = true

#   tags = merge(tomap({
#     Name = "${local.environment} MySQL Key"
#   }), local.common_tags)
# }

# resource "aws_kms_alias" "mysql_key" {
#   count = local.enable_central ? 1 : 0
#   name          = "alias/${local.envname}-${local.mysql_key_alias_suffix}"
#   target_key_id = aws_kms_key.mysql_key[0].key_id
# }

# # replicas
# resource "aws_kms_replica_key" "mysql_replica" {
#   count = local.enable_central ? 0 : 1
#   description             = "Replica key for mysql MSK encryption"
#   deletion_window_in_days = 7
#   primary_key_arn         = data.aws_kms_key.mysql_key[0].arn
# }

# resource "aws_kms_alias" "mysql_replica" {
#   count = local.enable_central ? 0 : 1
#   name          = "alias/${local.envname}-${local.mysql_key_alias_suffix}"
#   target_key_id = aws_kms_replica_key.mysql_replica[0].key_id
# }

# create a kms key for s3 encryption
# MAY NEED TO UNCOMMENT
resource "aws_kms_key" "s3_key" {
  count = local.enable_central ? 1 : 0
  description = "KMS key for S3 encryption"
  deletion_window_in_days = 7
  multi_region            = true

  tags = merge(tomap({
    Name = "${local.environment} S3 Key"
  }), local.common_tags)
}

resource "aws_kms_alias" "s3_key" {
  count = local.enable_central ? 1 : 0
  name          = "alias/${local.envname}-${local.s3_key_alias_suffix}"
  target_key_id = aws_kms_key.s3_key[0].key_id
}

# replicas
resource "aws_kms_replica_key" "s3_replica" {
  count = local.enable_central ? 0 : 1
  description             = "Replica key for s3 encryption"
  deletion_window_in_days = 7
  primary_key_arn         = data.aws_kms_key.s3_key[0].arn
}

resource "aws_kms_alias" "s3_replica" {
  count = local.enable_central ? 0 : 1
  name          = "alias/${local.envname}-${local.s3_key_alias_suffix}"
  target_key_id = aws_kms_replica_key.s3_replica[0].key_id
}


# ### s3 buckets ###
# resource "aws_s3_bucket" "slb_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.slb_s3
#   tags = merge(tomap({
#     Name = "${local.environment} SLB Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "slb_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.slb_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# resource "aws_s3_bucket" "app_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.app_s3

#   tags = merge(tomap({
#     Name = "${local.environment} App Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.app_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# resource "aws_s3_bucket" "rtp_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.rtp_s3

#   tags = merge(tomap({
#     Name = "${local.environment} RTP Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "rtp_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.rtp_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# resource "aws_s3_bucket" "hom_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.graf_s3

#   tags = merge(tomap({
#     Name = "${local.environment} Grafana Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket" "obs_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.obs_s3

#   tags = merge(tomap({
#     Name = "${local.environment} Observability Homer Qryn Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket" "sipp_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.sipp_s3

#   tags = merge(tomap({
#     Name = "${local.environment} Sipp script Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket" "clickhouse_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.clickhouse_s3

#   tags = merge(tomap({
#     Name = "${local.environment} Clickhouse Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "hom_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.hom_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "otel_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.obs_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# resource "aws_s3_bucket" "lambda_bucket" {
#   count = local.enable_central ? 1 : 0
#   bucket = local.lambda_s3

#   tags = merge(tomap({
#     Name = "${local.environment} Lambda Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_bucket_sse" {
#   count = local.enable_central ? 1 : 0
#   bucket = aws_s3_bucket.lambda_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

# # Make regional s3 Lambbda bucket
# resource "aws_s3_bucket" "regional_lambda_bucket" {
#   count = local.enable_central ? 0 : 1
#   bucket = "${local.lambda_s3}-${local.reg}"

#   tags = merge(tomap({
#     Name = "${local.environment} ${local.region} Lambda Bucket"
#   }), local.common_tags)
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "regional_lambda_bucket_sse" {
#   count = local.enable_central ? 0 : 1
#   bucket = aws_s3_bucket.regional_lambda_bucket[0].id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = "alias/${local.envname}-s3-key"
#     }
#   }
# }

### instance profiles ###
# MAY NEED TO UNCOMMENT
resource "aws_iam_role" "generic_role" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-GenericRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# resource "aws_iam_role" "lambda_role" {
#   for_each = local.lambda_names
#   name = "${local.envname}-${each.key}-role"

#   assume_role_policy = jsonencode({
#     Version   = "2012-10-17",
#     Statement = [
#       {
#         Action    = "sts:AssumeRole",
#         Effect    = "Allow",
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = merge(tomap({
#     Name = "${local.environment} ${each.key} Lambda Role"
#   }), local.common_tags)
# }

# #create generic instance profile
#MAY NEED TO UNCOMMENT
resource "aws_iam_instance_profile" "generic_instance_profile" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-InstanceGeneric"
  role = aws_iam_role.generic_role[0].name
}

#create generic instance policy
resource "aws_iam_policy" "ec2_instance_policy" {
  count = local.enable_central ? 1 : 0
  name        = "${local.envname}-GenericEC2InstancePolicy"
  description = "Policy to allow access to the ec2 api"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect": "Allow",
        "Action": "ec2:DescribeInstances",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "route53_policy" {
  count = local.enable_central ? 1 : 0
  name        = "${local.envname}-GenericRoute53Policy"
  description = "Policy to allow access to the route53 api"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_autoscale_lifecycle_policy" {
  count = local.enable_central ? 1 : 0
  name        = "${local.envname}-GenericAutoscaleLifecyclePolicy"
  description = "Policy to allow access respond to lifecycle events"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:CompleteLifecycleAction",
        ],
        "Resource" : "arn:aws:autoscaling:*:${var.account}:autoScalingGroup:*:autoScalingGroupName/${local.envname}-*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeLifecycleHooks"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_autoscale_instance_health_policy" {
  count = local.enable_central ? 1 : 0
  name        = "${local.envname}-GenericAutoscaleInstanceHealthPolicy"
  description = "Policy to allow access set health of instances"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetInstanceHealth",
        ],
        "Resource" : "arn:aws:autoscaling:*:${var.account}:autoScalingGroup:*:autoScalingGroupName/${local.envname}-*"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_access_policy" {
  name = "${local.envname}-GenericS3AccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${local.slb_s3}",
          "arn:aws:s3:::${local.slb_s3}/*",
          "arn:aws:s3:::${local.app_s3}",
          "arn:aws:s3:::${local.app_s3}/*",
          "arn:aws:s3:::${local.rtp_s3}",
          "arn:aws:s3:::${local.rtp_s3}/*",
          "arn:aws:s3:::${local.graf_s3}",
          "arn:aws:s3:::${local.graf_s3}/*",
          "arn:aws:s3:::${local.obs_s3}",
          "arn:aws:s3:::${local.obs_s3}/*",
          "arn:aws:s3:::${local.sipp_s3}",
          "arn:aws:s3:::${local.sipp_s3}/*",
          "arn:aws:s3:::${local.clickhouse_s3}",
          "arn:aws:s3:::${local.clickhouse_s3}/*",
          "arn:aws:s3:::wavecrest-terraform-ops-ew1-ai",
          "arn:aws:s3:::wavecrest-terraform-ops-ew1-ai/*",
          "arn:aws:s3:::wavecrest-terraform-ops-ew1",
          "arn:aws:s3:::wavecrest-terraform-ops-ew1/*"
        ]
      }
    ]
  })

  tags = merge(tomap({
    Name = "${local.environment} S3 Policy"
  }), local.common_tags)
}

resource "aws_iam_policy" "secrets_manager_policy" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-GenericSecretsManagerPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "secretsmanager:ListSecrets",
        "Resource" : "*"
      },
      # {
      #   "Effect" : "Allow",
      #   "Action" : "kafka:ListScramSecrets",
      #   "Resource" : [for colour in var.env_colours : "arn:aws:kafka:*:${var.account}:cluster/${local.envname}-*-kafka/*"]
      # },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ],
        "Resource" : "arn:aws:kms:*:${var.account}:key/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "kms:DescribeCustomKeyStores",
        "Resource" : "arn:aws:kms:*:${var.account}:key/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:getSecretValue",
          "secretsmanager:describeSecret",
          "secretsmanager:listSecrets"
        ],
        "Resource" : "arn:aws:secretsmanager:*:${var.account}:secret:*"
      }
    ]
  })
}

resource "aws_iam_policy" "logstash_push_policy" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-GenericLogstashPushPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:${var.account}:*"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_access_policy" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-GenericCloudWatchAccessPolicy"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "AllowReadingMetricsFromCloudWatch",
        Effect: "Allow",
        Action: [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ],
        Resource: "*"
      },
      {
        Sid: "AllowReadingLogsFromCloudWatch",
        Effect: "Allow",
        Action: [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ],
        Resource: "*"
      },
      {
        Sid: "AllowReadingTagsInstancesRegionsFromEC2",
        Effect: "Allow",
        Action: ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
        Resource: "*"
      },
      {
        Sid: "AllowReadingResourcesForTags",
        Effect: "Allow",
        Action: "tag:GetResources",
        Resource: "*"
      }
    ]

  })
}


#add policy to attach eips
resource "aws_iam_policy" "eip_attach_policy" {
  count = local.enable_central ? 1 : 0
  name = "${local.envname}-GenericEIPAttachPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

#Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.s3_access_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "logstash_push_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.logstash_push_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "secrets_manager_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.secrets_manager_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "eip_attach_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.eip_attach_policy[0].arn
  role      = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach_policy" {
  count = local.enable_central ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "ec2_autoscale_lifecycle_policy_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.ec2_autoscale_lifecycle_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access_policy_attachment" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.cloudwatch_access_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

resource "aws_iam_role_policy_attachment" "route53_policy" {
  count = local.enable_central ? 1 : 0
  policy_arn = aws_iam_policy.route53_policy[0].arn
  role       = aws_iam_role.generic_role[0].name
}

# resource "aws_iam_role_policy_attachment" "lambda_vpc_attach_policy" {
#   for_each = local.lambda_names

#   policy_arn = data.aws_iam_policy.AWSLambdaVPCAccessExecutionRole.arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_msk_attach_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_msk_trigger", false) == true
#   }

#   policy_arn = data.aws_iam_policy.AWSLambdaMSKExecutionRole.arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_secrets_manager", false) == true || lookup(config, "allow_msk_trigger", false) == true
#   }

#   policy_arn = aws_iam_policy.secrets_manager_policy[0].arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_ec2_describe_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_ec2_describe", false) == true
#   }

#   policy_arn = aws_iam_policy.ec2_instance_policy[0].arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_lifecycle_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_lifecycle_hooks", false) == true
#   }

#   policy_arn = aws_iam_policy.ec2_autoscale_lifecycle_policy[0].arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_autoscale_instance_health_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_autoscale_health", false) == true
#   }

#   policy_arn = aws_iam_policy.ec2_autoscale_instance_health_policy[0].arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

# resource "aws_iam_role_policy_attachment" "lambda_route53_policy" {
#   for_each = {
#     for name, config in local.lambda_names :
#     name => config if lookup(config, "allow_route53", false) == true
#   }

#   policy_arn = aws_iam_policy.route53_policy[0].arn
#   role       = aws_iam_role.lambda_role[each.key].name
# }

## create instance ssh keypair from secret manager secret
resource "aws_key_pair" "devops_ssh" {
  key_name   = "${local.envname}-${var.devops_sshkey_suffix}"
  public_key = "${data.aws_secretsmanager_secret_version.ssh_key.secret_string} ${local.envname}-${var.devops_sshkey_suffix}"

  tags = merge(tomap({
    Name = "${local.environment} DevOps SSH Key"
  }), local.common_tags)
}

# output "GenericProfile" {
#   value = aws_iam_instance_profile.generic_instance_profile.name
# }

provider "aws" {
  alias  = "central"
  region = "eu-west-1"
}