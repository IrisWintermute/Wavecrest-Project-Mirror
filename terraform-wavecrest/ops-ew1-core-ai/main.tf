data "aws_caller_identity" "current" {}

locals {
  config  = basename(path.cwd)
  account = data.aws_caller_identity.current.account_id
}

module "app" {
  source = "./tf-connect-asg"
  providers = {
    aws.central = aws.central
    aws         = aws
  }

  account = local.account
  config  = local.config

  name                 = "ai"
  asg_max_size         = 1
  asg_desired_capacity = 1
  disk_size            = 20
  instance_memory      = 1
  key_name             = "devops"
  location_subnet      = "private"
  nlb_subnet           = ""
  enable_kafka_envs    = false
  enable_db_envs       = false
  enable_qryn_envs     = false

  #builtins: any, localvpc, odine, both, allvpcs, allwc
  securitygroups = [
    { description = "ssh", protocol = "TCP", port = 22, to_port = 22, cidr_blocks = ["localvpc"], loadbalance = false },
  ]
  securitygroups_outbound = [
    { description = "any", protocol = "-1", port = 0, to_port = 0, cidr_blocks = ["any"] }
  ]

  # healthcheck on the port(s) described above
  healthcheck = { port = 22, protocol = "TCP", timeout = 2, interval = 5, healthy_threshold = 2,
    unhealthy_threshold = 2, path = null, matcher = null
  }

  enable_install = false #nothing to copy from s3
  user_data      = <<-EOF
              sed -i 's/^\(hosts:.*\) resolve \[!UNAVAIL=return\] \(.*\)$/\1 \2/' /etc/nsswitch.conf
              
              mkdir data
              aws s3 sync s3://wavecrest-terraform-ops-ew1 ./data --exclude "*.tfstate"
              # Additional setup and commands can be added here
              EOF

  ############################
  # change the below defaults if needed
  ############################

  # public_zone_name = "${local.envname}.network.wavecrest.com" # Only needed if not this default

  #Note ami needs to include wildcards here, if needed - otherwise it will look for a specific AMI
  ami                   = "amzn2-ami-hvm-*-x86_64-gp2"
  instance_architecture = "x86_64" # or arm64

  enable_weekdays_scale_down = true # Scale down at 6pm on weeknights
  enable_weekdays_scale_up   = true # Scale up at 6am on weekdays

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

provider "aws" {
  alias  = "central"
  region = "eu-west-1"
}
### Outputs

