resource "hcloud_server" "mgmt01" {
  name        = "mgmt01"
  server_type = var.mgmt_server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.demo.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = merge(local.common_labels, {
    node_role = "mgmt"
  })
}

resource "hcloud_server" "login01" {
  name        = "login01"
  server_type = var.login_server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.demo.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = merge(local.common_labels, {
    node_role = "login"
  })
}

resource "hcloud_server" "compute01" {
  name        = "compute01"
  server_type = var.compute_server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.demo.id]

  # Public IP needed for package installation (Hetzner private networks don't NAT)
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  # Private network for cluster communication
  network {
    network_id = hcloud_network.demo.id
    ip         = "10.0.0.31"
  }

  labels = merge(local.common_labels, {
    node_role = "compute"
  })

  depends_on = [hcloud_network_subnet.demo]
}

resource "hcloud_server" "compute02" {
  name        = "compute02"
  server_type = var.compute_server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.demo.id]

  # Public IP needed for package installation (Hetzner private networks don't NAT)
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  # Private network for cluster communication
  network {
    network_id = hcloud_network.demo.id
    ip         = "10.0.0.32"
  }

  labels = merge(local.common_labels, {
    node_role = "compute"
  })

  depends_on = [hcloud_network_subnet.demo]
}

resource "hcloud_server_network" "mgmt01" {
  server_id  = hcloud_server.mgmt01.id
  network_id = hcloud_network.demo.id
  ip         = "10.0.0.10"

  depends_on = [hcloud_network_subnet.demo]
}

resource "hcloud_server_network" "login01" {
  server_id  = hcloud_server.login01.id
  network_id = hcloud_network.demo.id
  ip         = "10.0.0.20"

  depends_on = [hcloud_network_subnet.demo]
}

# Note: compute01 and compute02 use inline network blocks
# because private-only servers require network at creation time
