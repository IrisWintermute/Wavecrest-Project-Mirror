resource "aws_security_group" "sg_asg" {
  name   = "${var.config} ASG"
  vpc_id = data.aws_vpc.colour_vpc.id

  dynamic "ingress" {
    for_each = toset([for sg in var.securitygroups : sg if sg.protocol != "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol == "HTTP" ? "TCP" : ingress.value.protocol
      cidr_blocks = lookup({
        "any"      = ["0.0.0.0/0"]
        "localvpc" = ["${data.aws_vpc.colour_vpc.cidr_block}"]
        "odine"    = ["${var.wavecrest_create_cidr}"]
        "both"     = ["${data.aws_vpc.colour_vpc.cidr_block}", "${var.wavecrest_create_cidr}"]
        "allvpcs"  = data.aws_ssm_parameters_by_path.all_vpc_cidrs.values
        "allwc"    = concat(data.aws_ssm_parameters_by_path.all_vpc_cidrs.values, [var.wavecrest_create_cidr])
      }, join(",", ingress.value.cidr_blocks), ingress.value.cidr_blocks)
    }
  }

  dynamic "ingress" {
    for_each = toset([for sg in var.securitygroups : sg if sg.protocol == "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.to_port
      protocol    = "TCP"
      cidr_blocks = lookup({
        "any"      = ["0.0.0.0/0"]
        "localvpc" = ["${data.aws_vpc.colour_vpc.cidr_block}"]
        "odine"    = ["${var.wavecrest_create_cidr}"]
        "both"     = ["${data.aws_vpc.colour_vpc.cidr_block}", "${var.wavecrest_create_cidr}"]
        "allvpcs"  = data.aws_ssm_parameters_by_path.all_vpc_cidrs.values
        "allwc"    = concat(data.aws_ssm_parameters_by_path.all_vpc_cidrs.values, [var.wavecrest_create_cidr])
      }, join(",", ingress.value.cidr_blocks), ingress.value.cidr_blocks)
    }
  }

  dynamic "ingress" {
    for_each = toset([for sg in var.securitygroups : sg if sg.protocol == "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.to_port
      protocol    = "UDP"
      cidr_blocks = lookup({
        "any"      = ["0.0.0.0/0"]
        "localvpc" = ["${data.aws_vpc.colour_vpc.cidr_block}"]
        "odine"    = ["${var.wavecrest_create_cidr}"]
        "both"     = ["${data.aws_vpc.colour_vpc.cidr_block}", "${var.wavecrest_create_cidr}"]
        "allvpcs"  = data.aws_ssm_parameters_by_path.all_vpc_cidrs.values
        "allwc"    = concat(data.aws_ssm_parameters_by_path.all_vpc_cidrs.values, [var.wavecrest_create_cidr])
      }, join(",", ingress.value.cidr_blocks), ingress.value.cidr_blocks)
    }
  }
  dynamic "egress" {
    for_each = toset(var.securitygroups_outbound)
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = lookup({
        "any"      = ["0.0.0.0/0"]
        "localvpc" = ["${data.aws_vpc.colour_vpc.cidr_block}"]
        "odine"    = ["${var.wavecrest_create_cidr}"]
        "both"     = ["${data.aws_vpc.colour_vpc.cidr_block}", "${var.wavecrest_create_cidr}"]
        "allvpcs"  = data.aws_ssm_parameters_by_path.all_vpc_cidrs.values
        "allwc"    = concat(data.aws_ssm_parameters_by_path.all_vpc_cidrs.values, [var.wavecrest_create_cidr])
      }, join(",", egress.value.cidr_blocks), [egress.value.cidr_blocks])
    }
  }

  tags = merge(tomap({
    Name = "${var.config} ASG"
  }), local.common_tags)
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.1.0"

  name            = "${local.envname}-${local.reg}-${local.colour}-${var.name}"
  use_name_prefix = false
  credit_specification = {
    cpu_credits = var.instance_burstable ? "standard" : "unlimited"
  }
  min_size                        = 0
  max_size                        = var.asg_max_size
  desired_capacity                = var.asg_desired_capacity
  ignore_desired_capacity_changes = true # this is to prevent terraform from resetting the desired capacity when running terraform apply
  wait_for_capacity_timeout       = 0
  health_check_type               = length(local.sg_with_loadbalancer) > 0 && !var.disable_elb_monitoring ? "ELB" : "EC2"
  #availability_zones        = local.azs # default all
  vpc_zone_identifier = data.aws_subnets.location_subs.ids
  security_groups     = [aws_security_group.sg_asg.id]
  # Launch template
  create_launch_template          = true
  launch_template_name            = var.launch_template
  launch_template_use_name_prefix = true
  launch_template_description     = "${var.config} Launch template"
  update_default_version          = true
  launch_template_version         = "$Latest"

  image_id          = data.aws_ami.ami.id
  instance_type     = local.cheapest_instance
  ebs_optimized     = true
  enable_monitoring = true
  user_data         = base64encode(local.user_data)
  key_name          = var.key_name != "" ? "${local.envname}-${var.key_name}" : null

  create_iam_instance_profile = false
  iam_instance_profile_arn    = "arn:aws:iam::${var.account}:instance-profile/${local.envname}-InstanceGeneric"

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = var.disk_size
        volume_type           = "gp2"
      }
    }
  ]

  ## if below is enabled it will make them spot instances
  # instance_market_options = {
  #   market_type = "spot"
  # }

  #You must create a token before curl to metadata service will work
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  initial_lifecycle_hooks = var.enable_lifecycle_hooks ? [
    {
      name                 = "launch_hook"
      default_result       = "ABANDON"
      heartbeat_timeout    = var.lifecycle_launch_hook_heartbeat
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    },
    {
      name                 = "terminate_hook"
      default_result       = "ABANDON"
      heartbeat_timeout    = var.lifecycle_terminate_hook_heartbeat
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    }
  ] : []

  target_group_arns = flatten([module.public_alb.target_group_arns, module.private_alb.target_group_arns, module.public_nlb.target_group_arns, module.private_nlb.target_group_arns])

  # can't do this in the module - need to refactor and use direct terraform
  #  lifecycle {
  #    ignore_changes = [min_size]
  #  }

  tags = merge(tomap({
    Name                = "${var.config} ASG"
    propagate_at_launch = true
  }), local.common_tags)
}


resource "aws_autoscaling_schedule" "weekdays-scale-down" {
  count                  = var.enable_weekdays_scale_down ? 1 : 0
  scheduled_action_name  = "weekdays-scale-down"
  min_size               = 0
  max_size               = var.asg_max_size
  recurrence             = var.scale_down_recurrence
  time_zone              = "Europe/London"
  desired_capacity       = 0
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
}

resource "aws_autoscaling_schedule" "weekdays-scale-up" {
  count                  = var.enable_weekdays_scale_up ? 1 : 0
  scheduled_action_name  = "weekdays-scale-up"
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  recurrence             = var.scale_up_recurrence
  time_zone              = "Europe/London"
  desired_capacity       = var.asg_scaleup_capacity != null ? var.asg_scaleup_capacity : var.asg_desired_capacity
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
}

resource "aws_autoscaling_policy" "target-tracking-policy" {
  count                  = var.enable_target_tracking_scaling ? 1 : 0
  name                   = "${module.autoscaling.autoscaling_group_name}-target-tracking-policy"
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
  policy_type            = "TargetTrackingScaling"


  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.scaling_plan_asg_average_cpu_utilization
  }
}

resource "aws_autoscaling_policy" "predictive-policy" {
  count                  = var.enable_predictive_scaling ? 1 : 0
  name                   = "${module.autoscaling.autoscaling_group_name}-predictive-policy"
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
  policy_type            = "PredictiveScaling"

  predictive_scaling_configuration {
    metric_specification {
      target_value = var.scaling_plan_asg_average_cpu_utilization
      predefined_metric_pair_specification {
        predefined_metric_type = "ASGCPUUtilization"
        resource_label         = "${module.autoscaling.autoscaling_group_name}-predictive-metric-pair"
      }
    }
    mode                         = "ForecastAndScale"
    scheduling_buffer_time       = 10
    max_capacity_breach_behavior = "IncreaseMaxCapacity"
    max_capacity_buffer          = 10
  }
}

######
# NLB
######

module "public_nlb" {
  source           = "./loadbalancer"
  loadbalance_rule = local.public_nlb
  healthcheck      = var.healthcheck
  config           = var.config
  public_zone_name = var.public_zone_name
}

module "private_nlb" {
  source           = "./loadbalancer"
  loadbalance_rule = local.private_nlb
  healthcheck      = var.healthcheck
  config           = var.config
  public_zone_name = var.public_zone_name
}

module "public_alb" {
  source           = "./loadbalancer"
  loadbalance_rule = local.public_alb
  healthcheck      = var.healthcheck
  config           = var.config
  public_zone_name = var.public_zone_name
}

module "private_alb" {
  source           = "./loadbalancer"
  loadbalance_rule = local.private_alb
  healthcheck      = var.healthcheck
  config           = var.config
  public_zone_name = var.public_zone_name
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
      configuration_aliases = [ aws, aws.central ]
    }
  }
}

#   output reserved_eips_map 

output "original_eips" {
  value = data.aws_eips.reserved_eips
}

output "reserved_eip_list" {
  value = local.reserved_eips_map
}