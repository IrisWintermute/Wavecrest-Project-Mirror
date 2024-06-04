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

#### Specific ####

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
}

variable  "private_zone_name_suffix" {
  type        = string
  description = "Private zone name"
}

variable "public_zone_name" {
  type        = string
  default     = ""
  description = "Public zone name"
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT gateway"
}

variable "reserved_slb_eips" {
  type        = number
  default     = 0
  description = "Number of reserved EIPs for SLB"
}

variable "reserved_rtp_eips" {
  type        = number
  default     = 0
  description = "Number of reserved EIPs for RTP"
}

variable "reserved_sipp_carrier_eips" {
  type        = number
  default     = 0
  description = "Number of reserved EIPs for sipp carrier"
}

variable "reserved_sipp_customer_eips" {
  type        = number
  default     = 0
  description = "Number of reserved EIPs for sipp customer"
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

variable "wavecrest_create_cidr" {
  type = string
  description = "Wavecrest CIDR"
  default = "10.50.193.0/24"
}