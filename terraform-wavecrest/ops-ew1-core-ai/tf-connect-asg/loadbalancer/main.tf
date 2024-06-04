resource "aws_security_group" "lb_asg" {
  count  = length(var.loadbalance_rule) > 0 ? 1 : 0
  name   = "${local.name} ${var.loadbalance_rule[0].protocol == "HTTP" ? "ALB" : "NLB"} ASG"
  vpc_id = data.aws_vpc.colour_vpc.id


  dynamic "ingress" {
    for_each = toset([for lr in var.loadbalance_rule : lr if lr.protocol != "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.loadbalancer_port
      to_port     = ingress.value.loadbalancer_port
      protocol    = ingress.value.loadbalancer_protocol == "HTTPS" || ingress.value.loadbalancer_protocol == "HTTP" || ingress.value.loadbalancer_protocol == "TLS"? "TCP" : ingress.value.loadbalancer_protocol
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = toset([for lr in var.loadbalance_rule : lr if lr.protocol == "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.loadbalancer_port
      to_port     = ingress.value.loadbalancer_port
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = toset([for lr in var.loadbalance_rule : lr if lr.protocol == "TCP_UDP"])
    content {
      description = ingress.value.description
      from_port   = ingress.value.loadbalancer_port
      to_port     = ingress.value.loadbalancer_port
      protocol    = "UDP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(tomap({
    Name = "${local.name} ALB ASG"
  }), local.common_tags)
}

resource "aws_lb" "asg-lb" {
  count              = length(var.loadbalance_rule) > 0 ? 1 : 0
  name               = local.name
  internal           = var.loadbalance_rule[0].loadbalancer_subnet == "public" ? false : true
  load_balancer_type = var.loadbalance_rule[0].protocol == "HTTP" ||  var.loadbalance_rule[0].protocol == "HTTPS" ? "application" : "network"
  security_groups    = [aws_security_group.lb_asg[0].id]

  enable_cross_zone_load_balancing = false
  subnets                          = var.loadbalance_rule[0].loadbalancer_subnet == "public" ? data.aws_subnets.nlb_public_subs.ids : data.aws_subnets.nlb_private_subs.ids
  enable_deletion_protection       = false

  tags = merge(tomap({
    Name = "${var.config}-${var.loadbalance_rule[0].loadbalancer_subnet}-${var.loadbalance_rule[0].protocol == "HTTP" ? "alb" : "nlb"}"
    Network = var.loadbalance_rule[0].loadbalancer_subnet
  }), local.common_tags)
}

resource "aws_route53_record" "asg-lb-dns" {
  count   = length(var.loadbalance_rule)
  zone_id = var.loadbalance_rule[count.index].loadbalancer_dns_public ? data.aws_route53_zone.public_zone.zone_id : data.aws_route53_zone.private_zone.zone_id
  name    = "${var.loadbalance_rule[count.index].loadbalancer_domain_name}.${var.loadbalance_rule[count.index].loadbalancer_dns_public ? data.aws_route53_zone.public_zone.name : data.aws_route53_zone.private_zone.name}"
  type    = "CNAME"
  records = [aws_lb.asg-lb[0].dns_name]
  ttl     = 60
}

resource "aws_lb_target_group" "asg-tg" {
  count       = length(var.loadbalance_rule)
  name        = "${local.name}-${count.index}"
  port        = tostring(var.loadbalance_rule[count.index].port)
  protocol    = var.loadbalance_rule[count.index].protocol
  vpc_id      = data.aws_vpc.colour_vpc.id
  target_type = "instance"

  deregistration_delay = "0"

  dynamic "stickiness" {
    for_each = var.loadbalance_rule[count.index].protocol != "HTTP" ? [1] : []
    content {
      type    = "source_ip"
      enabled = false
    }
  }

  health_check {
    enabled = true

    port                = var.healthcheck.port
    protocol            = var.healthcheck.protocol
    timeout             = var.healthcheck.timeout
    interval            = var.healthcheck.interval
    healthy_threshold   = var.healthcheck.healthy_threshold
    unhealthy_threshold = var.healthcheck.unhealthy_threshold
    path                = var.healthcheck.path
    matcher             = var.healthcheck.matcher
  }

  tags = merge(tomap({
    Name = "${local.name}-${var.loadbalance_rule[count.index].port}"
  }), local.common_tags)
}

resource "aws_lb_listener" "listener" {
  count             = length(var.loadbalance_rule)
  load_balancer_arn = aws_lb.asg-lb[0].arn
  protocol          = var.loadbalance_rule[count.index].loadbalancer_protocol
  port              = var.loadbalance_rule[count.index].loadbalancer_port
  certificate_arn   = (var.loadbalance_rule[count.index].loadbalancer_protocol == "HTTPS" || var.loadbalance_rule[count.index].loadbalancer_protocol == "TLS") ? data.aws_acm_certificate.public.arn : null
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg-tg[count.index].id
  }
}

output "target_group_arns" {
  value = aws_lb_target_group.asg-tg[*].arn
}

output "ip_addrs" {
  value = flatten(data.dns_a_record_set.ip_addresses[*].addrs)
}

output "lb_domains" {
  value = aws_route53_record.asg-lb-dns[*].name
}