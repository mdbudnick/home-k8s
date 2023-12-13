#!/bin/bash

echo "Running nmap to discover network devices"
nmap_output=$(nmap -sn '10.109.89.*' | grep 'Nmap scan report for' | awk '{print $5}')

echo "Collecting device details with arp - a"
arp_output=$(arp -a | grep -v incomplete)

inventory_file="/tmp/k8s_inventory"
echo "[k8s_cluster:children]" >> "$inventory_file"
echo "k8s_controlplane_nodes" >> "$inventory_file"
echo "k8s_worker_nodes" >> "$inventory_file"
echo "" >> "$inventory_file"
echo "Initialized a master inventory file"

controlplane_file="/tmp/k8s_controlplanes"
echo "[k8s_controlplane_nodes]" >> "$controlplane_file"
controlplane_counter=0
echo "Initialized a controlplane inventory file"

workernode_file="/tmp/k8s_workernodes"
echo "[k8s_worker_nodes]" >> "$workernode_file"
workernode_counter=0
echo "Initialized worker node inventory file"

# Process arp_output and generate inventory entries
while read -r entry; do
    
    hostname=$(echo "$entry" | awk '{print $1}')
    ip=$(echo "$entry" | awk '{print $2}' | tr -d '()')

    if [[ $hostname =~ wyse ]]; then
        echo "Found $hostname at $ip, adding as controlplane-$controlplane_counter"
        echo "controlplane-$controlplane_counter ansible_host=$ip" >> "$controlplane_file"
        ((controlplane_counter++))
    fi

    if [[ $hostname =~ pi.*k8s ]]; then
        echo "Found $hostname at $ip, adding as workernode-$workernode_counter"
        echo "workernode-$workernode_counter ansible_host=$ip" >> "$workernode_file"
        ((workernode_counter++))
    fi
done <<< "$arp_output"

cat "$controlplane_file" >> "$inventory_file"
echo "" >> "$inventory_file"
cat "$workernode_file" >> "$inventory_file"
echo "" >> "$inventory_file"

echo "Generated inventory file:"
echo ""
cat "$inventory_file"
