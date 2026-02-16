variable "cluster_name" {
  description = "Label prefix for all demo resources"
  type        = string
  default     = "rcd-demo"
}

variable "location" {
  description = "Hetzner location code (Hillsboro US West = hil)"
  type        = string
  default     = "hil"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "us-west"
}

variable "network_ip_range" {
  description = "Private network address range"
  type        = string
  default     = "10.0.0.0/8"
}

variable "subnet_cidr" {
  description = "Private subnet range for demo nodes"
  type        = string
  default     = "10.0.0.0/24"
}

variable "image" {
  description = "Hetzner image name"
  type        = string
  default     = "rocky-9"
}

variable "mgmt_server_type" {
  description = "Server type for mgmt01"
  type        = string
  default     = "cpx21"
}

variable "login_server_type" {
  description = "Server type for login01"
  type        = string
  default     = "cpx11"
}

variable "compute_server_type" {
  description = "Server type for compute nodes"
  type        = string
  default     = "cpx11"
}

variable "ttl_hours" {
  description = "TTL warning threshold in hours"
  type        = number
  default     = 4

  validation {
    condition     = var.ttl_hours >= 1
    error_message = "ttl_hours must be at least 1 hour."
  }
}

variable "ssh_key_path" {
  description = "Optional override path to SSH public key"
  type        = string
  default     = ""
}
