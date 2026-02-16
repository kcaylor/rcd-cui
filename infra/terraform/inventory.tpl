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
          ansible_host: ${compute01_private_ip}
          ansible_user: root
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -i ${ssh_private_key_path} -W %h:%p root@${mgmt_public_ip}"'
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: ${compute02_private_ip}
          ansible_user: root
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -i ${ssh_private_key_path} -W %h:%p root@${mgmt_public_ip}"'
          node_role: compute
          zone: restricted
