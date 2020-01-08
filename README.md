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
- Go to [https://install.iccluster.epfl.ch/](https://install.iccluster.epfl.ch/)
- Navigate to `My Servers` > `Setup`
- Add the created server to the 'setup list'
- Choose boot option `Ubuntu bionic amd64 installation via network 1804`
- Select __no__ customization, enter our root password (ask Thijs)
- Run setup
- Wait for ~20 min until the 'boot option' under `My Servers` > `List` has become 'Boot OS from local hard disk'.
- Now run ansible with `ansible-playbook -i hosts/mlo main.yml -k` and enter the root password.

## Deploying a playbook
1. Determine on which hosts you want to deploy. Potentially, you can make a new file in the directory `hosts/` for your selection.
2. Run ```ansible-playbook -i hosts/mlo main.yml -k```

## Organization
`main.yml` is the main playbook. The root directory of this folder also contains `user-specific` playbooks that can install stuff under their own username.

Playbooks can import 'roles' from the `roles/` directory. These are self-contained installations that are designed to be reusable.
