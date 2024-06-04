
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tf_repo = basename(path.module)
  envname = split("-", var.config)[0]
  reg     = split("-", var.config)[1]
  colour  = split("-", var.config)[2]
  part    = split("-", var.config)[3]

  region = lookup({
    "ew1" = "eu-west-1"
    "ec1" = "eu-central-1"
    "uw1" = "us-west-1"
    "ue2" = "us-east-2"
    "as1" = "ap-south-1"
    "se1" = "sa-east-1"
  }, local.reg, "eu-west-1")

  environment = lookup({
    "dev" = "Develop"
    "tst" = "Test"
    "prd" = "Production"
    "ops" = "Operations"
  }, local.envname, "develop")

  common_tags = {
    CreatedBy      = "Terraform"
    Repo           = local.tf_repo
    Config         = var.config
    Colour         = local.colour
    Region         = local.region
    CostIdentifier = "Voice Network"
    map-migrated   = "mig8VPS82KVFO"
  }

  location = "${local.envname}-${local.reg}-${local.colour}"

  sg_with_loadbalancer = [for sg in var.securitygroups :
    {
      description               = sg.description
      protocol                  = sg.protocol
      port                      = sg.port
      to_port                   = sg.to_port
      cidr_blocks               = sg.cidr_blocks
      loadbalance               = sg.loadbalance
      loadbalancer_subnet       = sg.loadbalancer_subnet != null ? sg.loadbalancer_subnet : "public"
      loadbalancer_port         = sg.loadbalancer_port != null ? sg.loadbalancer_port : sg.port
      loadbalancer_protocol     = sg.loadbalancer_protocol != null ? sg.loadbalancer_protocol : sg.protocol
      loadbalancer_dns_public   = sg.loadbalancer_dns_public != null ? sg.loadbalancer_dns_public : (sg.loadbalancer_subnet == "public" || sg.loadbalancer_subnet == null) ? true : false
      loadbalancer_domain_name  = sg.loadbalancer_domain_name != null ? "${sg.loadbalancer_domain_name}-${local.colour}-${local.reg}" : "${local.servertype}-${local.colour}-${local.reg}"
  } if sg.loadbalance == true]

  public_nlb  = [for sg in local.sg_with_loadbalancer : sg if sg.loadbalancer_subnet == "public" && sg.protocol != "HTTP"]
  public_alb  = [for sg in local.sg_with_loadbalancer : sg if sg.loadbalancer_subnet == "public" && sg.protocol == "HTTP"]
  private_nlb = [for sg in local.sg_with_loadbalancer : sg if sg.loadbalancer_subnet == "private" && sg.protocol != "HTTP"]
  private_alb = [for sg in local.sg_with_loadbalancer : sg if sg.loadbalancer_subnet == "private" && sg.protocol == "HTTP"]

  instances_by_price = {for instance in data.aws_ec2_spot_price.instance_price : instance.spot_price => instance.instance_type... }
  cheapest_instance = local.instances_by_price[sort(keys(local.instances_by_price))[0]][0]

  #for dns
  servertype       = local.part
  normal_public_zone_name = "${local.envname}" == "prd" ? "network.wavecrest.com" : "${local.envname}.network.wavecrest.com"
  public_zone_name = "${var.public_zone_name}" == "" ? "${local.normal_public_zone_name}" : "${var.public_zone_name}"

  #create list of eips to attach
  reserved_eips_map = join("\n", [for eip in data.aws_eip.reserved_eips_info : "reserved_eips[\"${eip.id}\"]=\"${eip.tags["Name"]}\""])

  # otel_target = "otel-${local.colour}-${local.reg}.${local.public_zone_name}:${var.otel_target_port}"
  # loki_target = "http://loki-${local.colour}-${local.reg}.${local.public_zone_name}:${var.loki_target_port}"

  central_reg = "ew1"

  wavecrest_vars = <<-EOF
    echo "Starting Wavecrest Code -------------------------"
    export AWS_REGION="${local.region}"
    export AWS_ENVIRONMENT="${local.envname}"
    export SERVICE_ENVIRONMENT="${local.envname}"
    export SERVICE_SHORT_REGION="${local.reg}"
    export SERVICE_COLOUR="${local.colour}"

    #Get access token
    export TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    export AWS_INSTANCE_ID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id`
    # # dns
    # export DMQ_DOMAIN="dmq-slb.${data.aws_route53_zone.private_zone.name}"
    # export HOMER_IP="homer-${local.colour}-${local.reg}.${data.aws_route53_zone.public_zone.name}"
    # # kamailio
    # export SERVICE_CONF_DIR="/etc/kamailio/commands/"
    # # urls
    # export VOICENET_PROVISIONING_URL="http://provisioning.${data.aws_route53_zone.private_zone.name}/api/v1"
    # #for script use:
    # echo "#!/bin/bash" > /tmp/voicenet_provisioning_url
    # echo "export VOICENET_PROVISIONING_URL=http://provisioning.${data.aws_route53_zone.private_zone.name}/api/v1" >> /tmp/voicenet_provisioning_url
  EOF

  ## install_ssm
  install_ssm_pkg = strcontains(var.ami, "arm64") ? "https://s3.${local.region}.amazonaws.com/amazon-ssm-${local.region}/latest/debian_arm64/amazon-ssm-agent.deb" : "https://s3.${local.region}.amazonaws.com/amazon-ssm-${local.region}/latest/debian_amd64/amazon-ssm-agent.deb"
  install_ssm     = <<-EOF
    echo "Installing SSM"
    mkdir /tmp/ssm
    cd /tmp/ssm
    wget ${local.install_ssm_pkg}
    sudo dpkg -i amazon-ssm-agent.deb
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    echo "Finished installing SSM"
  EOF

  ubuntu_admin = <<-EOF
    # setup admin account from ubuntu account to simplify ssh access
    useradd -m -s /bin/bash -g admin admin
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/admin
    mkdir /home/admin/.ssh
    chown admin:admin /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    cp /home/ubuntu/.ssh/authorized_keys /home/admin/.ssh/authorized_keys
    chown admin:admin /home/admin/.ssh/authorized_keys
    echo "Finished setting up admin account on Ubuntu"
  EOF

  # attach_eips = <<-EOF
  #   loop=0
  #   declare -A reserved_eips
  #   ${local.reserved_eips_map}

  #   echo "Finding free EIP from list of :  $${!reserved_eips[@]}"
  #   eips=`aws ec2 describe-addresses --output table --query 'Addresses[*].PublicIp'`
  #   echo "EIPs in env: "
  #   echo "$${eips}"

  #   while [[ $${loop} -le 3 ]]; do
  #     let loop++
  #     echo "loop $${loop} out of 3"
  #     for eip_alloc in $${!reserved_eips[@]}; do
  #       echo "Checking $${eip_alloc}"
  #       ISFREE=`aws ec2 describe-addresses --allocation-ids $${eip_alloc} --query 'Addresses[0].InstanceId' --output text`
  #       if [ "$${ISFREE}" == "None" ]; then
  #         echo "Attaching $${eip_alloc}"
  #         aws ec2 associate-address --instance-id $${AWS_INSTANCE_ID} --allocation-id $${eip_alloc}
  #         sleep 5 # in case it's stolen by another server
  #         export AWS_NEW_PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4`
  #         echo "Public IP is now $${AWS_NEW_PUBLIC_IP}"
  #         if [[ "$${eips}" == *"$${AWS_NEW_PUBLIC_IP}"* ]]; then
  #           echo "EIP attached successfully"
  #           export AWS_EIP=$${eip_alloc}
  #           break
  #         else
  #           echo "Public IP is now $${AWS_NEW_PUBLIC_IP} - but not in EIP list. Trying again"
  #         fi
  #       fi
  #     done
  #     export AWS_NEW_PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4`
  #     if [[ "$${eips}" == *"$${AWS_NEW_PUBLIC_IP}"* ]]; then
  #       echo "No need to loop any more"
  #       break
  #     fi
  #   done

  #   echo "Finished attaching EIPs"
  #   if [[ "$${eips}" != *"$${AWS_NEW_PUBLIC_IP}"* ]]; then
  #     echo "ERROR: EIP not attached - no more elastic IPs left?"
  #     init 0 # do not continue without one
  #   fi
  # EOF

  # #kafka_envs
  # kafka_secret_json = var.enable_kafka_envs ? jsondecode(data.aws_secretsmanager_secret_version.kafka_password[0].secret_string) : { "username" = "false", "password" = "false" }
  # kafka_servers     = var.enable_kafka_envs ? "${data.aws_msk_cluster.kafka_cluster[0].bootstrap_brokers_sasl_scram}" : ""
  # kafka_envs        = <<-EOF
  #   # kafka
  #   export KAFKA_BOOTSTRAP_SERVERS="${local.kafka_servers}"
  #   export KAFKA_USER="${local.kafka_secret_json.username}"
  #   export KAFKA_PASSWORD="${local.kafka_secret_json.password}"
  #   export KAFKA_CALL_EVENT_TOPIC="${var.kafka_call_event_topic_name}"
  #   export KAFKA_MONITORING_TOPIC="${var.kafka_monitoring_topic_name}"
  #   export KAFKA_BROKERS="${local.kafka_servers}"
  #   export KAFKA_SECRET_NAME="AmazonMSK_kafka-${local.envname}-${local.colour}"
  #   export KAFKA_REGION="${local.region}"
  #   export KAFKA_TOPIC="${var.kafka_server_event_topic_name}"
  # EOF

  # abiban_secret_json = jsondecode(data.aws_secretsmanager_secret_version.api_ban_secret_version.secret_string)
  # apiban_envs        = <<-EOF
  #   # API BAN
  #   export APIBAN_KEY="${local.abiban_secret_json.api_key}"
  # EOF

  # clickhouse_secret_json = jsondecode(data.aws_secretsmanager_secret_version.clickhouse_secret_version.secret_string)
  # clickhouse_envs        = <<-EOF
  #   # clickhouse
  #   export CLICKHOUSE_SERVER="clickhouse-core-${local.central_reg}.${data.aws_route53_zone.public_zone.name}"
  #   export CLICKHOUSE_NATIVE_SERVER="clickhouse-native-core-${local.central_reg}.${data.aws_route53_zone.public_zone.name}"
  #   export CLICKHOUSE_USER="default"
  #   export CLICKHOUSE_PASSWORD="${local.clickhouse_secret_json.password}"
  #   export CLICKHOUSE_DB="qryn"
  #   export CLICKHOUSE_PROTO="https"
  #   export CLICKHOUSE_PORT="8443"
  #   export CLICKHOUSE_NATIVE_PORT="9440"
  # EOF

  # opsgenie_secret_json = jsondecode(data.aws_secretsmanager_secret_version.opsgenie_secret_version.secret_string)
  # opsgenie_envs        = <<-EOF
  #   # opsgenie
  #   export OPS_GENIE_API_KEY="${local.opsgenie_secret_json.api_key}"
  #   export OPS_GENIE_API_URL="https://api.opsgenie.com/v2/alerts"
  #   export ENABLE_ALERTING=${var.enable_grafana_alerts}
  # EOF

  # grafana_oauth_secret_json = jsondecode(data.aws_secretsmanager_secret_version.grafana_oauth_secret.secret_string)
  # grafana_oauth_envs        = <<-EOF
  #   # grafana oauth
  #   export OAUTH_GRAFANA_CLIENT_ID="${local.grafana_oauth_secret_json.client_id}"
  #   export OAUTH_GRAFANA_CLIENT_SECRET="${local.grafana_oauth_secret_json.client_secret}"
  #   export OAUTH_TENANT_ID="${local.grafana_oauth_secret_json.tenant_id}"
  #   export GRAFANA_DOMAIN="${length(module.public_alb.lb_domains) > 0 ? module.public_alb.lb_domains[0] : ""}"
  # EOF

  # #db_envs
  # database_secret_json       = var.enable_db_envs ? jsondecode(data.aws_secretsmanager_secret_version.mysql_password[0].secret_string) : { "viewer" = "" }
  # db_cluster_master_username = var.enable_db_envs ? "viewer" : "false"
  # db_cluster_endpoint        = var.enable_db_envs ? "${data.aws_rds_cluster.mysql[0].endpoint}" : "false"
  # db_cluster_database_name   = var.enable_db_envs ? "${data.aws_rds_cluster.mysql[0].database_name}" : "false"
  # db_envs                    = <<-EOF
  #   # db
  #   export SQL_USER="${local.db_cluster_master_username}"
  #   export SQL_PASSWORD="${local.database_secret_json.viewer}"
  #   export SQL_HOST="${local.db_cluster_endpoint}"
  #   export SQL_DATABASE="${local.db_cluster_database_name}"
  # EOF

  # # qyrn_envs
  # qryn_secret_json = var.enable_qryn_envs ? jsondecode(data.aws_secretsmanager_secret_version.qryn_password[0].secret_string) : { "username" = "false", "password" = "false" }
  # qyrn_envs        = <<-EOF
  #   # qyrn
  #   export QRYN_SERVER='http://qryn-${local.colour}-${local.reg}.${data.aws_route53_zone.public_zone.name}:3100'
  #   export QRYN_SERVER_WITH_AUTH='http://admin:${urlencode(local.qryn_secret_json.password)}@qryn-${local.colour}-${local.reg}.${data.aws_route53_zone.public_zone.name}:3100'
  #   export QRYN_USER="admin"
  #   export QRYN_PORT="3100"
  #   export QRYN_PASSWORD="${local.qryn_secret_json.password}"
  # EOF

  # commands_envs = <<-EOF
  #   # commands service
  #   export COMMANDS_SERVICE_ENVIRONMENT="${local.envname}"
  #   export COMMANDS_SERVICE_SHORT_REGION="${local.reg}"
  #   export COMMANDS_SERVICE_COLOUR="${local.colour}"
  #   export COMMANDS_SERVICE_NAME="${local.location}-${local.servertype}-commands"

  #   # zap logger
  #   export COMMANDS_LOGGER_LEVEL="info"
  #   export COMMANDS_LOGGER_DEV_MODE="false"
  #   export COMMANDS_LOGGER_ENCODER="json"
	# // this control how much log will be sent the collector. 0 = info level.
  #   export COMMANDS_LOGGER_CORE_MIN_LEVEL="0"

  #   # zap log loki pusher
  #   export COMMANDS_ZAPLOKI_URL="${local.loki_target}"
  #   export COMMANDS_ZAPLOKI_BATCH_SIZE="1"
  #   export COMMANDS_ZAPLOKI_BATCH_WAIT="10s"
  #   export COMMANDS_ZAPLOKI_USERNAME=""
  #   export COMMANDS_ZAPLOKI_PASSWORD=""
  #   # otel traces
  #   export COMMANDS_OTEL_TARGET="${local.otel_target}"
  #   export COMMANDS_OTEL_TRACER_NAME="${local.location}-${local.servertype}"
  # EOF

  # stats_collector_envs = <<-EOF
  #   # commands service
  #   export STATS_SERVICE_ENVIRONMENT="${local.envname}"
  #   export STATS_SERVICE_SHORT_REGION="${local.reg}"
  #   export STATS_SERVICE_COLOUR="${local.colour}"
  #   export STATS_SERVICE_NAME="${local.location}-${local.servertype}-stats_collector"

  #   # zap logger
  #   export STATS_LOGGER_LEVEL="info"
  #   export STATS_LOGGER_DEV_MODE="false"
  #   export STATS_LOGGER_ENCODER="json"
	# // this control how much log will be sent the collector. 0 = info level.
  #   export STATS_LOGGER_CORE_MIN_LEVEL="0"

  #   # zap log loki pusher
  #   export STATS_ZAPLOKI_URL="${local.loki_target}"
  #   export STATS_ZAPLOKI_BATCH_SIZE="1"
  #   export STATS_ZAPLOKI_BATCH_WAIT="10s"
  #   export STATS_ZAPLOKI_USERNAME=""
  #   export STATS_ZAPLOKI_PASSWORD=""
  #   # otel traces
  #   export STATS_OTEL_TARGET="${local.otel_target}"
  #   export STATS_OTEL_TRACER_NAME="${local.location}-${local.servertype}-stats_collector"
  # EOF

  # slb_domains = [
  #   "slb-${local.colour}-${local.reg}.${data.aws_route53_zone.public_zone.name}",
  #   "slb-private-${local.colour}-${local.reg}.${data.aws_route53_zone.public_zone.name}",
  #   "slb.${local.colour}.${local.reg}.${data.aws_route53_zone.public_zone.name}", # DNS SRV record
  #   "$${reserved_eips[$AWS_EIP]}.${data.aws_route53_zone.public_zone.name}",

  #   # colourless domains
  #   "slb-${local.reg}.${data.aws_route53_zone.public_zone.name}",
  #   "slb-private-${local.reg}.${data.aws_route53_zone.public_zone.name}",
  #   "slb.${local.reg}.${data.aws_route53_zone.public_zone.name}", # DNS SRV record
  #   "$(echo $${reserved_eips[$AWS_EIP]} |cut -d '-' -f 1,2,4,5).${data.aws_route53_zone.public_zone.name}",

  #   # anycast domain
  #   "slb.${data.aws_route53_zone.public_zone.name}",
  # ]

  # slb_domain_alias_list = flatten([
  #   # all the domains for the slb
  #   local.slb_domains,

  #   # all the ip addresses for the slb
  #   module.public_nlb.ip_addrs,
  #   data.aws_globalaccelerator_accelerator.anycast.ip_sets[*].ip_addresses,

  # ])

  # slb_certbot_args = flatten([
  #   "certonly",
  #   local.envname == "prd" ? "" : "--test-cert",
  #   "--agree-tos",
  #   "-m",
  #   "dev@wavecrest.com",
  #   "--non-interactive",
  #   "--post-hook=\"kamcmd tls.reload\"",
  #   "--dns-route53",
  #   "--dns-route53-propagation-seconds",
  #   "30",
  #   [for domain in local.slb_domains : ["-d", domain]],

  # ])

  # slb_domain_alias_envs = <<-EOF
  #   export ALIAS_DOMAINS="${join(" ", local.slb_domain_alias_list)}"
  # EOF

  # app_server_secret_json = var.enable_app_server_envs ? jsondecode(data.aws_secretsmanager_secret_version.app_server_secret[0].secret_string) : { "secret" = "" }

  # app_server_envs = <<-EOF
  #    # app server specific variables
  #   export APP_AUTH_SECRET="${local.app_server_secret_json.secret}"
  # EOF

  # setup_slb_certbot = <<-EOF
  #   while ! sudo -u kamailio certbot ${join(" ", local.slb_certbot_args)}; do
  #       echo "Certbot failed, retrying"
  #       sleep 1
  #   done
  # EOF

  setup_fix_hostname = <<-EOF
    # Fix hostname
    if grep -q $HOSTNAME /etc/hosts; then
      echo "Hostname already in /etc/hosts"
    else
      echo "Adding hostname to /etc/hosts"
      TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
      LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4`

      echo -e "$LOCAL_IP\t$HOSTNAME" >> /etc/hosts

    fi
  EOF

  user_data = <<-EOF
    #!/bin/bash
    ${var.enable_install ? "if [ -d ${var.install_to} ]; then rm ${var.install_to}*; fi; aws s3 cp 's3://${local.envname}-${var.install_from}' ${var.install_to} --recursive" : ""}
    ${local.wavecrest_vars}

    ${local.setup_fix_hostname}

    ${var.install_ssm ? local.install_ssm : ""}

    ${strcontains(var.ami, "ubuntu") ? local.ubuntu_admin : ""}

    ${var.user_data}
    echo "ENV now:"
    env
  EOF
    # ${var.install_slb_certbot ? local.setup_slb_certbot : ""}
    # ${var.enable_kafka_envs ? local.kafka_envs : ""}
    # ${var.enable_db_envs ? local.db_envs : ""}
    # ${var.enable_qryn_envs ? local.qyrn_envs : ""}
    # ${var.enable_clickhouse_envs ? local.clickhouse_envs : ""}
    # ${var.enable_opsgenie_envs ? local.opsgenie_envs : ""}
    # ${var.enable_commands_envs ? local.commands_envs : ""}
    # ${var.enable_stats_collector_envs ? local.stats_collector_envs : ""}
    # ${var.enable_apiban_envs ? local.apiban_envs : ""}
    # ${local.part == "grafana" ? local.grafana_oauth_envs : ""}
    # ${var.enable_slb_domain_alias_envs ? local.slb_domain_alias_envs : ""}
    # ${var.enable_app_server_envs ? local.app_server_envs : ""}
    # ${var.use_eips ? local.attach_eips : ""}

}