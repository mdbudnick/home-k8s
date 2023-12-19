# Automated Multi-Architecture Ansible Playbook for Home Kubernetes Cluster

## Overview

This project facilitates the automated deployment of a multi-architecture Kubernetes cluster within a home environment. By setting up nodes on your local network with the appropriate host naming schema and generating an inventory file, you can run the `tasks/main.yml` Ansible playbook to install Kubernetes on your home cluster automatically. This setup includes updating node packages, adding a security role, and installing a Kubernetes cluster along with `kubectl` on the localhost where the playbook is executed. With minimal setup and a few commands, you can establish your own Kubernetes cluster effortlessly.

## Personal Kubernetes Cluster Details

This repository was tested by deploying a cluster with AMD64 Control Planes and Arm64 (Raspberry Pi) Worker nodes. For more detailed information, please visit the [project website](https://mdbudnick.github.io/home-k8s/).

### [Project Website](https://mdbudnick.github.io/home-k8s/)

## Usage

1. Prepare a cluster with the proper naming schema (see [Host Naming Schema](#host-naming-schema) below).
2. Configure the cluster hosts to be usable with Ansible; consult the [Ansible Docs](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html) for more details.
3. Generate the inventory for your cluster (check the [inventory/example.ini](/inventory/example.ini) file) by calling [generate_inventory.py](./generate_inventory.py). See the `generate_inventory.py` section below for more details about its usage.
4. Set the desired parameters in the kubespray submodule (particularly [kubespray/roles/kubespray-defaults/defaults/main.yaml](/kubespray/roles/kubespray-defaults/defaults/main.yaml)).
   - Please note, the kubespray submodule has been forked off and tested with [kubespray v2.23.1](https://github.com/kubernetes-sigs/kubespray/releases/tag/v2.23.1) which will constrain your parameter options.
   - Check the manually added commits to the end of the kubespray submodule to see what was modified from the default [here](https://github.com/kubernetes-sigs/kubespray/compare/release-2.23...mdbudnick:kubespray:home-k8s-submodule). For example, `kube_owner` will probably need to be set to the user you prefer (or reverted to kube).
5. Run the following command:

   ```bash
   ansible-playbook -i <inventory-file> --become --become-user=root --user=<connection-user> tasks/main.yml -kK
   ```
6. Watch as your Ansible cluster is automatically configured 

### Caveats
One of the major caveats with this is that you will need to use the same sudo password for all of the machines, including the host it is run on. This is a limitation of Ansible and discussion is outside the scope of this manual.

## Generating the inventory file
While it is possible to manually create the inventory file for the playbook, following [kubespray's example.ini](/kubespray/inventory/sample/inventory.ini), and using the inventory file generator (or doing it manually) this project also includes the generatedInventory.py script that can automate the process. The requirement to use the script is to name your nodes so that they will be organized correctly in the inventory file.

### Host Naming Schema for Inventory Generation
1. Each of the desired kubernetes nodes hostnames requires either 'k8sm' or 'k8sw', to denote if it is part of the control-plane or a worker node, respectively
2. Optionally, if you want to have etcd in your cluster, 'etcd' can be added into the host names that you want to run the etcd cluster on.
   1. Please note, it is recommended to run etcd on at least 3 nodes in your cluster.

### generate_inventory.py
1. Set the network_ip_base to the base of the network where the target machines are
2. There are the following flags for the script:
   - -t --target-file requires a single parameter: the target file output for the generated inventory
   - - o --output will set the output format of the inventory, acceptable values are ini or json
   - -n -IPs will set the network ips of the machines you want to include in your cluster, also accepts wildcards like "192.186.0.*"
   - -v is "verbose mode" and will send out strings to stdout throughout the script in order to aid in debugging
   - - q --quiet is "quiet mode", and the completed inventory will not be output to stdout at the end of the script.

Please note, generate_inventory.py can also be used as a dynamic inventory script, for example:
`ansible-playbook -i "./generate_inventory.py -n 192.168.0.*" --become --become-user=root --user=mb tasks/main.yml -kK
`


