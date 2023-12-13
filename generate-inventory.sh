#!/bin/bash

target_file=false
quiet_mode=false
verbose=false

while getopts ":qtd:" opt; do
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
nmap_output=$(nmap -sn '10.109.89.*' | grep 'Nmap scan report for' | awk '{print $5}')

if $verbose; then
    echo "Collecting device details with arp - a"
fi
arp_output=$(arp -a | grep -v incomplete)

inventory_file="/tmp/k8s_inventory"
echo "[k8s_cluster:children]" >> "$inventory_file"
echo "k8s_controlplane_nodes, k8s_worker_nodes" >> "$inventory_file"
echo "" >> "$inventory_file"
if $verbose; then
    echo "Initialized a master inventory file"
fi

controlplane_file="/tmp/k8s_controlplanes"
echo "[k8s_controlplane_nodes]" >> "$controlplane_file"
controlplane_counter=0
if $verbose; then
    echo "Initialized a controlplane inventory file"
fi

workernode_file="/tmp/k8s_workernodes"
echo "[k8s_worker_nodes]" >> "$workernode_file"
workernode_counter=0
if $verbose; then
    echo "Initialized worker node inventory file"
fi

# Process arp_output and generate inventory entries
while read -r entry; do
    
    hostname=$(echo "$entry" | awk '{print $1}')
    ip=$(echo "$entry" | awk '{print $2}' | tr -d '()')

    if [[ $hostname =~ wyse ]]; then
        if $verbose; then
            echo "Found $hostname at $ip, adding as controlplane-$controlplane_counter"
        fi
        echo "controlplane-$controlplane_counter ansible_host=$ip" >> "$controlplane_file"
        ((controlplane_counter++))
    fi

    if [[ $hostname =~ pi.*k8s ]]; then
        if $verbose; then
            echo "Found $hostname at $ip, adding as workernode-$workernode_counter"
        fi
        echo "workernode-$workernode_counter ansible_host=$ip" >> "$workernode_file"
        ((workernode_counter++))
    fi
done <<< "$arp_output"

cat "$controlplane_file" >> "$inventory_file"
echo "" >> "$inventory_file"
cat "$workernode_file" >> "$inventory_file"
echo "" >> "$inventory_file"

if $verbose; then
    echo "Generated inventory file:"
    echo ""
fi
if ! $quiet_mode; then
    cat "$inventory_file"
fi

if $target_file; then
    cp "$inventory_file" "$target_file"
    if $verbose; then
        echo "Created inventory file at $target_file"
    fi
fi

rm "$inventory_file"
rm "$controlplane_file"
rm "$workernode_file"
