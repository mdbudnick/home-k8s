#!/bin/bash

quiet_mode=false
verbose=false
target_file=""

network_ip_base='10.109.89.*'

while getopts ":qvt:" opt; do
  case $opt in
    q)
      quiet_mode=true
      ;;
    v)
      verbose=true
      ;;
    t)
      target_file="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if $verbose; then
    echo "Running nmap to discover network devices"
fi
nmap_output=$(nmap -sn $network_ip_base | grep 'Nmap scan report for' | awk '{print $5}')

if $verbose; then
    echo "Collecting device details with arp - a"
fi
arp_output=$(arp -a | grep -v incomplete)

inventory_file="/tmp/k8s_inventory.ini"

controlplane_nodes=()
controlplane_node_ips=()
controlplane_counter=1
workernodes=()
workernode_ips=()
workernode_counter=1
etcd_nodes=()
etcd_counter=1

# Process arp_output and generate array entries
while read -r entry; do
    
    hostname=$(echo "$entry" | awk '{print $1}')
    ip=$(echo "$entry" | awk '{print $2}' | tr -d '()')

    if [[ $hostname =~ k8sm ]]; then
        if $verbose; then
            echo "Found $hostname at $ip, adding as controlplane-$controlplane_counter and as etcd host"
        fi
        node="controlplane-$controlplane_counter"
        controlplane_nodes+=("$node")
        controlplane_node_ips+=("$ip")
        ((controlplane_counter++))
    fi

    if [[ $hostname =~ k8sw ]]; then
        if $verbose; then
            echo "Found $hostname at $ip, adding as workernode-$workernode_counter"
        fi
        node="workernode-$workernode_counter"
        workernodes+=("$node")
        workernode_ips+=("$ip")
        ((workernode_counter++))
    fi
    
    if [[ $hostname =~ etcd ]]; then
        if $verbose; then
            echo "Adding $hostname as etcd node"
        fi
        etcd_nodes+=("$node")
    fi
done <<< "$arp_output"

# Build inventory file with controlplane_nodes, etcdnodes and workernodes

# Add ansible hosts
for i in ${!controlplane_nodes[@]}; do
    host="${controlplane_nodes[$i]} ansible_host=${controlplane_node_ips[$i]}" 
    if [[ " ${etcd_nodes[@]} " =~ " ${controlplane_nodes[$i]} " ]]; then
        host+=" etcd_member_name=etcd$etcd_counter"
        (( etcd_counter++ ))
    fi
    echo "$host" >> "$inventory_file"
done

for i in ${!workernodes[@]}; do
    host="${workernodes[$i]} ansible_host=${workernode_ips[$i]}"
    if [[ " ${etcd_nodes[@]} " =~ " ${workernodes[$i]} " ]]; then
        host+=" etcd_member_name=etcd$etcd_counter"
        (( etcd_counter++ ))
    fi
    echo "$host" >> "$inventory_file"
done

# Create ansible groups https://github.com/kubernetes-sigs/kubespray/blob/24632ae81beafbab9710718705d266536b1bf1ec/docs/ansible.md
echo "" >> "$inventory_file"
echo "[kube_control_plane]" >> "$inventory_file"
for n in ${controlplane_nodes[@]}; do
    echo "$n" >> "$inventory_file"
done

echo "" >> "$inventory_file"
echo "[kube_node:vars]" >> "$inventory_file"
echo "host_architecture="amd64""

echo "" >> "$inventory_file"
echo "[etcd]" >> "$inventory_file"
for n in ${etcd_nodes[@]}; do
    echo "$n" >> "$inventory_file"
done

echo "" >> "$inventory_file"
echo "[kube_node]" >> "$inventory_file"
for n in ${workernodes[@]}; do
    echo "$n" >> "$inventory_file"
done

echo "" >> "$inventory_file"
echo "[kube_node:vars]" >> "$inventory_file"
echo "host_architecture="arm64""


echo "" >> "$inventory_file"
echo "[k8s_cluster:children]" >> "$inventory_file"
echo "kube_control_plane" >> "$inventory_file"
echo "kube_node" >> "$inventory_file"

if $verbose; then
    echo "Generated inventory file:"
    echo ""
fi
if ! $quiet_mode; then
    cat "$inventory_file"
fi

if [ -n "${target_file}" ]; then
    cp "$inventory_file" "$target_file"
    if $verbose; then
        echo "Created inventory file at $target_file"
    fi
fi

rm "$inventory_file"
