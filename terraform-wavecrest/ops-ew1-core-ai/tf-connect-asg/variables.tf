variable "region" {
  type        = string
  default     = ""
  description = "AWS Region"
}

variable "tf_repo" {
  type        = string
  default     = ""
  description = "Name of the repo"
}

variable "config" {
  type        = string
  default     = ""
  description = "Name of the config folder"
}

variable "colour" {
  type        = string
  default     = ""
  description = "Colour of the environment"
}

variable "envname" {
  type        = string
  default     = ""
  description = "Short version of environment, e.g. 'prd', 'dev', 'tst', 'ops'"
}

variable "environment" {
  type        = string
  default     = ""
  description = "Long version of environment, e.g. 'Production', 'Develop', 'Test', 'Operations'"
}

variable "account" {
  type        = string
  default     = ""
  description = "AWS Account ID"
}

### Wavecrest specific ###

variable "wavecrest_create_cidr" {
  type        = string
  description = "Wavecrest CIDR"
  default     = "10.50.193.0/24"
}

#### Specific ####

variable "name" {
  type        = string
  default     = ""
  description = "Name of the ASG"
}

variable "asg_max_size" {
  type        = number
  default     = 0
  description = "Maximum size of the ASG"
}

variable "asg_min_size" {
  type        = number
  default     = 0
  description = "Minimum size of the ASG"
}

variable "scale_up_recurrence" {
  type        = string
  default     = "0 6 * * 1-5"
  description = "Scale up recurrence"
}

variable "scale_down_recurrence" {
  type        = string
  default     = "0 18 * * 1-5"
  description = "Scale down recurrence"
}

variable "asg_desired_capacity" {
  type        = number
  default     = 0
  description = "Desired capacity of the ASG"
}

variable "asg_scaleup_capacity" {
  type        = number
  default     = null
  description = "Desired capacity of the ASG when daily scaling up"
}

variable "disk_size" {
  type        = number
  default     = 0
  description = "Disk size of the instance"
}

variable "instance_family" {
  type        = string
  default     = ""
  description = "Instance type"
}

variable "instance_burstable" {
  type        = bool
  default     = true
  description = "Instance type"
}

variable "instance_num_cpus" {
  type        = number
  default     = 2
  description = "Instance type"
}

variable "instance_architecture" {
  type        = string
  default     = "arm64"
  description = "Instance architecture"
}

variable "instance_memory"  {
  type        = number
  default     = 4
  description = "Instance memory"
}

variable "key_name" {
  type        = string
  default     = ""
  description = "SSH key name"
}

variable "location_subnet" {
  type        = string
  default     = ""
  description = "Name of the ASG subnets"
}

variable "nlb_subnet" {
  type        = string
  default     = ""
  description = "Name of NLB subnets"
}

variable "ami" {
  type        = string
  default     = ""
  description = "AMI to use"
}

variable "securitygroups" {
  type = list(object({
    description               = string
    protocol                  = string
    port                      = number
    to_port                   = number
    cidr_blocks               = list(string)
    loadbalance               = bool
    loadbalancer_ingress_port = optional(number)
    loadbalancer_subnet       = optional(string)
    loadbalancer_port         = optional(number)
    loadbalancer_protocol     = optional(string)
    loadbalancer_dns_public   = optional(bool)
    loadbalancer_domain_name  = optional(string)


  }))
  default = [{ description = "ssh",
    protocol    = "TCP",
    port        = 22,
    to_port     = 0,
    cidr_blocks = ["localvpc"],
  loadbalance = false }]
  description = "List of inbound security traffic"
}

variable "securitygroups_outbound" {
  type = list(object({
    description = string
    protocol    = string
    port        = number
    to_port     = number
    cidr_blocks = list(string)
  }))
  default     = [{ description = "any", protocol = "-1", port = 0, to_port = 0, cidr_blocks = ["any"] }]
  description = "List of outbound security traffic"
}

variable "healthcheck" {
  type = object({
    port                = number
    protocol            = string
    timeout             = number
    interval            = number
    healthy_threshold   = number
    unhealthy_threshold = number
    path                = string
    matcher             = string
  })
  default     = { port = 8080, protocol = "HTTP", timeout = 5, interval = 30, healthy_threshold = 2, unhealthy_threshold = 2, path = null, matcher = null }
  description = "Healthcheck for the ASG"
}

variable "launch_template" {
  type        = string
  default     = ""
  description = "Launch template name"
}

variable "user_data" {
  type        = string
  default     = ""
  description = "User data"
}

variable "enable_weekdays_scale_down" {
  type        = bool
  default     = false
  description = "Enable weekdays Out Of Hours scale down nightly"
}

variable "enable_weekdays_scale_up" {
  type        = bool
  default     = false
  description = "Enable weekdays morning scale up"
}

variable "enable_predictive_scaling" {
  type        = bool
  default     = false
  description = "Enable predictive scaling plan"
}

variable "enable_target_tracking_scaling" {
  type        = bool
  default     = false
  description = "Enable target tracking (dynamic) scaling plan"
}

variable "scaling_plan_asg_average_cpu_utilization" {
  type        = string
  default     = "60"
  description = "sets the ASGAverageCPUUtilization in auto scaling plan"
}

variable "kafka_server_event_topic_name" {
  type        = string
  default     = "voicenet.app.server"
  description = "Kafka Server Event Topic Name"
}

variable "kafka_monitoring_topic_name" {
  type        = string
  default     = "voicenet.monitoring"
  description = "Kafka monitoring topic name"
}

variable "kafka_call_event_topic_name" {
  type        = string
  default     = "voicenet.call.events"
  description = "Kafka Call Event Topic Name"
}

variable "public_zone_name" {
  type        = string
  default     = ""
  description = "Public zone name"
}

variable "use_eips" {
  type        = bool
  default     = false
  description = "Use EIPs for ASG instances"
}

variable "enable_kafka_envs" {
  type        = bool
  default     = false
  description = "Enable Kafka environment variables"
}

variable "enable_clickhouse_envs" {
  type        = bool
  default     = false
  description = "Enable Clickhouse environment variables"
}

variable "enable_opsgenie_envs" {
  type        = bool
  default     = false
  description = "Enable Opsgenie environment variables"
}

variable "enable_grafana_alerts" {
    type        = bool
    default     = false
    description = "Enable Grafana alerts"

}

variable "enable_commands_envs" {
  type        = bool
  default     = false
  description = "Enable Commands environment variables"
}

variable "enable_stats_collector_envs" {
  type        = bool
  default     = false
  description = "Enable stats collector environment variables"
}

variable "enable_db_envs" {
  type        = bool
  default     = false
  description = "Enable MariaDB environment variables"
}

variable "enable_qryn_envs" {
  type        = bool
  default     = false
  description = "Enable Qryn environment variables"
}

variable "enable_apiban_envs" {
  type        = bool
  default     = false
  description = "Enable apiban environment variables"
}

variable "enable_slb_domain_alias_envs" {
  type        = bool
  default     = false
  description = "Enable slb domain alias environment variables"
}

variable "install_slb_certbot" {
  type        = bool
  default     = false
  description = "Install certbot for the slb"
}

variable "enable_app_server_envs" {
  type        = bool
  default     = false
  description = "Enable app-server specific environment variables"
}

variable "enable_lifecycle_hooks" {
  type        = bool
  default     = false
  description = "Enable ASG lifecycle hooks"
}

variable "lifecycle_launch_hook_heartbeat" {
  type        = number
  default     = 300
  description = "timeout for the ASG lifecycle launch hook"
}

variable "lifecycle_terminate_hook_heartbeat" {
  type        = number
  default     = 300
  description = "timeout for the ASG terminate launch hook"
}

variable "disable_elb_monitoring" {
  type        = bool
  default     = false
  description = "Disable ELB monitoring even if a loadbalancer is attached"
}


variable "enable_install" {
  type        = bool
  default     = false
  description = "Enable install"
}

variable "install_from" {
  type        = string
  default     = ""
  description = "Install from"
}

variable "install_to" {
  type        = string
  default     = ""
  description = "Install to"
}

variable "otel_target_port" {
  type        = string
  default     = "4317"
  description = "Otel target port"
}

variable "loki_target_port" {
  type        = string
  default     = "4100"
  description = "loki target port"
}

variable "install_ssm" {
  type        = bool
  default     = true
  description = "Install SSM"
}

variable "central_region" {
  type        = string
  default     = "eu-west-1"
  description = "Central region"
}

variable "current_region" {
  type        = string
  default     = "eu-west-1"
  description = "Current region"
}