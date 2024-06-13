variable "account" {
  type        = string
  default     = ""
  description = "AWS Account ID"
}

variable "config" {
  type        = string
  default     = ""
  description = "Name of the config folder"
}

#### Specific ####

variable "public_zone_name" {
  type        = string
  default     = ""
  description = "Public zone name"
}

variable "vpn_secret" {
  type        = map(string)
  default     = { location = "vpn_key", secret_key = "preshared_key" }
  description = "Secrets"
}

variable "api-ban_secret" {
  type        = map(string)
  default     = { location = "apiban", secret_key = "api_key" }
  description = "Secrets"
}

variable "kafka_secret" {
  type        = map(string)
  default     = { location = "AmazonMSK_kafka", username = "admin", secret_key = "password" }
  description = "Secrets"
}

variable "number_of_secrets" {
  type    = number
  default = 11
}

variable "public_zone_cert" {
  type    = bool
  default = true
}

variable "mysql_secret" {
  type        = map(string)
  default     = { location = "mysql", secret_key = "password" }
  description = "Secrets"
}

variable "app_auth_secret" {
  type        = map(string)
  default     = { location = "app_auth", secret_key = "secret" }
  description = "Secrets"
}

variable "devops_sshkey_location" {
  type        = string
  default     = "devops-sshkey"
  description = "Location of the devops ssh key"
}

variable "devops_sshkey_suffix" {
  type        = string
  default     = "devops"
  description = "Name of the devops ssh key"
}

variable "env_colours" {
  type        = list(string)
  default     = ["blue", "green", "core"]
  description = "List of env colours"
}

variable "clickhouse_secret" {
  type        = map(string)
  default     = { location = "clickhouse", secret_key = "password" }
  description = "Secrets"
}

variable "qryn_secret" {
  type        = map(string)
  default     = { location = "qryn", secret_key = "password" }
  description = "Secrets"
}

variable "opsgenie_secret" {
  type        = map(string)
  default     = { location = "opsgenie", secret_key = "api_key" }
  description = "Secrets"
}

variable "grafana_oauth_secret" {
  type        = map(string)
  default     = { location = "grafana", tenant_id = "tenant_id", client_id= "client_id", client_secret = "client_secret" }
  description = "Secrets"
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

variable "provisioning_api_secret" {
  type        = map(string)
  default     = { location = "provisioning_api", secret_key = "api_key" }
  description = "Secrets"
}