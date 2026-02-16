all:
  vars:
    ansible_ssh_private_key_file: ${ssh_private_key_path}
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: ${mgmt_public_ip}
          ansible_user: root
          private_ip: ${mgmt_private_ip}
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: ${login_public_ip}
          ansible_user: root
          private_ip: ${login_private_ip}
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: ${compute01_public_ip}
          ansible_user: root
          private_ip: ${compute01_private_ip}
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: ${compute02_public_ip}
          ansible_user: root
          private_ip: ${compute02_private_ip}
          node_role: compute
          zone: restricted
