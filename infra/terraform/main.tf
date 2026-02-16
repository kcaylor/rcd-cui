terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.45.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0"
    }
  }
}

provider "hcloud" {}

locals {
  default_ssh_key_ed25519 = pathexpand("~/.ssh/id_ed25519.pub")
  default_ssh_key_rsa     = pathexpand("~/.ssh/id_rsa.pub")

  detected_ssh_key_path = fileexists(local.default_ssh_key_ed25519) ? local.default_ssh_key_ed25519 : (
    fileexists(local.default_ssh_key_rsa) ? local.default_ssh_key_rsa : ""
  )

  effective_ssh_key_path = trimspace(var.ssh_key_path) != "" ? pathexpand(var.ssh_key_path) : local.detected_ssh_key_path

  ssh_public_key = local.effective_ssh_key_path != "" ? (fileexists(local.effective_ssh_key_path) ? trimspace(file(local.effective_ssh_key_path)) : "") : ""

  # Hetzner labels don't allow colons, so use Unix timestamp for created_at
  common_labels = {
    cluster    = var.cluster_name
    ttl        = "${var.ttl_hours}h"
    created_at = time_static.cluster_created_at.unix
    managed_by = "terraform"
  }
}

resource "time_static" "cluster_created_at" {}

resource "hcloud_ssh_key" "demo" {
  name       = "${var.cluster_name}-key"
  public_key = local.ssh_public_key
  labels     = local.common_labels

  lifecycle {
    precondition {
      condition     = local.ssh_public_key != ""
      error_message = "No SSH public key found. Set TF_VAR_ssh_key_path, DEMO_SSH_KEY, or create ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub."
    }
  }
}

resource "hcloud_network" "demo" {
  name     = "${var.cluster_name}-network"
  ip_range = var.network_ip_range
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "demo" {
  network_id   = hcloud_network.demo.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.yml"
  content = templatefile("${path.module}/inventory.tpl", {
    mgmt_public_ip       = hcloud_server.mgmt01.ipv4_address
    login_public_ip      = hcloud_server.login01.ipv4_address
    mgmt_private_ip      = hcloud_server_network.mgmt01.ip
    login_private_ip     = hcloud_server_network.login01.ip
    compute01_private_ip = one(hcloud_server.compute01.network).ip
    compute02_private_ip = one(hcloud_server.compute02.network).ip
    ssh_private_key_path = "/workspace/infra/.ssh/demo_ed25519"
  })
  file_permission = "0644"
}
