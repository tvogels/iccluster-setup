# MLO IC Cluster Nodes

This is an attempt to simplify deployment of software and configuration to our IC Cluster ‘Hardware as a Service’ nodes.

This is built on top of Ansible, a managment tool for administering multiple computers together. It is based on declarative config files named playbooks:

> You describe the desired state of the machine

Playbooks should be idempotent. You can run them as often as you want, and they will do the minimal updates required to get the state of the target machines right.

Example:

```yaml
# Example part of a playbook
- name: Install public key for passwordless access
  authorized_key:
    user: vogels
    state: present
    key: '{{ item }}'
  with_file:
    - public_keys/id_vogels_epfl.pub
    - public_keys/id_rsa.pub
- name: .profile
  copy:  # SCP to the remote machine if the remote file is absent or different
    src: profile
    dest: ~/.profile
```


## Setup
Install [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html): 

```bash
pip install ansible
```

## Adding a new iccluster node
Choose a clean Ubuntu 18.04 node without MLO customization. Use the agreed upon root password.

## Deploying a playbook
1. Determine on which hosts you want to deploy. Potentially, you can make a new file in the directory `hosts/` for your selection.
2. Run ```ansible-playbook -i hosts/rank1-neurips main.yml -k```

## Organization
`main.yml` is the main playbook. The root directory of this folder also contains `user-specific` playbooks that can install stuff under their own username.

Playbooks can import 'roles' from the `roles/` directory. These are self-contained installations that are designed to be reusable.
