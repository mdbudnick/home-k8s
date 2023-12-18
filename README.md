# Automated Multi-Architecture Ansible playbook for Home Kubernetes Cluster

## Overview
After setting up nodes on your local network with the proper host naming schema, and generating a inventory file, the tasks/main.yml ansible playbook can be run to install Kubernetes on a home cluster automatically. This setup will update the node packages and add a best practice security role, before installing a Kubernetes cluster on them along with kubectl on the localhost where the playbook is run. With a little bit of setup and a couple of commands you have your own kubernetes cluster, voila!

This repo was tested on a cluster with AMD64 Control Planes and Arm64 (Raspberry Pi) Worker nodes, please see the project website for more detailed information.

## Usage
1. Prepare a cluster with the proper naming schema, see [Host Naming Schema](#Host Naming Schema) below
2. Configure the cluster hosts to be usable with Ansible; consult the [Ansible Docs](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html) for more details
3. Generate the inventory for your cluster (check the [inventory/example.ini](/inventory/example.ini) file) by calling [generate-inventory.sh](./generate-inventory.sh) See the generate-inventory.sh below for more details about its usage
4. Set the desired parameters in the kubespray submodule (particularly [kubespray/roles/kubespray-defaults/defaults/main.yaml](/kubespray/roles/kubespray-defaults/defaults/main.yaml))
   1. Please note, the kubespray submodule has been forked off and tested with [kubespray v2.23.1](https://github.com/kubernetes-sigs/kubespray/releases/tag/v2.23.1) which will constrain your parameter options
   2. Please check the manually added commits to the end of the kubespray submodule to see what was modified from the default [here](https://github.com/kubernetes-sigs/kubespray/compare/release-2.23...mdbudnick:kubespray:home-k8s-submodule). For example, `kube_owner` will probably be need to be set to the user you prefer (or reverted to kube).
5. Run `ansible-playbook -i <inventory-file> --become --become-user=root --user=<connection-user>  tasks/main.yml -kK`
6. Watch as your Kubernetes cluster is automatically configured! (It takes about an hour.)


## Generating the inventory file
While it is possible to manually create the inventory file for the playbook, following [kubespray's example.ini](/kubespray/inventory/sample/inventory.ini), this project also includes a script that can automate the process. The requirement to use the script is to name your nodes so that they will be organized correctly in the inventory file.

### Host Naming Schema for Inventory Generation
1. Each of the desired kubernetes nodes hostnames requires either 'k8sm' or 'k8sw', to denote if it is part of the control-plane or a worker node, respectively
2. Optionally, if you want to have etcd in your cluster, 'etcd' can be added into the host names that you want to run the etcd cluster on.
   1. Please note, it is recommended to run etcd on at least 3 nodes in your cluster.

### generate-inventory.sh
1. Set the network_ip_base to the base of the network where the target machines are
2. There are 3 flags for the script, -q -v and -t
    - -q is "quiet mode", and the completed inventory will not be output to stdout at the end of the script.
    - -t requires a single parameter: the target file output for the generated inventory
    - -v is "verbose mode" and will send out strings to stdout throughout the script in order to aid in debugging
  
  Example usage: ./generate-inventory.sh -t inventory/cluster.ini


