output "mgmt01_ip" {
  description = "Public IPv4 address for mgmt01"
  value       = hcloud_server.mgmt01.ipv4_address
}

output "login01_ip" {
  description = "Public IPv4 address for login01"
  value       = hcloud_server.login01.ipv4_address
}

output "compute01_ip" {
  description = "Public IPv4 address for compute01"
  value       = hcloud_server.compute01.ipv4_address
}

output "compute02_ip" {
  description = "Public IPv4 address for compute02"
  value       = hcloud_server.compute02.ipv4_address
}

output "private_ips" {
  description = "Private IP addresses for all nodes"
  value = {
    mgmt01    = hcloud_server_network.mgmt01.ip
    login01   = hcloud_server_network.login01.ip
    compute01 = one(hcloud_server.compute01.network).ip
    compute02 = one(hcloud_server.compute02.network).ip
  }
}

output "inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = abspath(local_file.ansible_inventory.filename)
}

output "cluster_created_at" {
  description = "Cluster creation timestamp used for TTL warnings"
  value       = time_static.cluster_created_at.rfc3339
}

output "ttl_hours" {
  description = "TTL threshold in hours"
  value       = var.ttl_hours
}

output "cluster_name" {
  description = "Cluster label used to identify demo resources"
  value       = var.cluster_name
}
