variable "loadbalance_rule" {
  type = list(object({
    description               = string
    protocol                  = string
    port                      = number
    to_port                   = number
    cidr_blocks               = list(string)
    loadbalance               = bool
    loadbalancer_subnet       = string
    loadbalancer_port         = number
    loadbalancer_protocol     = string
    loadbalancer_dns_public   = bool
    loadbalancer_domain_name  = string
  }))
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

variable "config" {
  type        = string
  default     = ""
  description = "Name of the config folder"
}

variable "public_zone_name" {
  type        = string
  default     = ""
  description = "Public zone name"
}