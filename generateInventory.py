#!/usr/bin/env python3
import argparse
import subprocess

def run_nmap(ip, verbose):
    try:
        nmap_output = subprocess.check_output(['nmap', '-sn', ip], universal_newlines=True)
        if verbose:
            print(f"Scan report for {ip}:\n{nmap_output}")
        return nmap_output
    except subprocess.CalledProcessError as e:
        print(f"Error running nmap for {ip}: {e}")
        return ""

def parse_args():
    parser = argparse.ArgumentParser(description="Generate Kubernetes inventory from ARP and nmap scans.")
    parser.add_argument('-n', '--ips', metavar='IPs', type=str, help='Comma-separated list of IP addresses')
    parser.add_argument('-q', '--quiet', action='store_true', help='Quiet mode (do not output result)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose mode (stdout for debugging)')
    parser.add_argument('-t', '--target-file', metavar='TARGET_FILE', type=str, help='Save result to the specified file')
    return parser.parse_args()

def get_cpu_architecture(hostname):
            if 'amd64' in hostname:
                return "amd64"
            elif 'arm' in hostname:
                return "arm"
            elif 'arm64' in hostname:
                return "arm64"

            return None              

def main():
    args = parse_args()

    if args.verbose:
        print(f"Running nmap to discover network devices for {args.ips}")

    network_ips = args.ips.split(',') if args.ips else []
    for ip in network_ips:
        run_nmap(ip, args.verbose)

    if args.verbose:
        print("Collecting device details with arp -a")

    arp_output = subprocess.check_output(['arp', '-a']).decode('utf-8')
    arp_lines = arp_output.splitlines()

    inventory_file = "/tmp/k8s_inventory.ini"
    controlplane_nodes = []
    worker_nodes = []
    etcd_nodes = []

    for entry in arp_lines:
        hostname = entry.split()[0]
        ip = entry.split()[1].strip('()')
        node = {"ip": ip}

        if 'k8sm' in hostname:
            node["name"] = f"controlplane-{len(controlplane_nodes) + 1}"
            cpu_architecture = get_cpu_architecture(hostname)
            if cpu_architecture:
                node["cpu_architecture"] = cpu_architecture
            if args.verbose:
                print(f"Found {hostname} at {ip}, adding as controlplane {node}")
            
            controlplane_nodes.append(node)

        if 'k8sw' in hostname:
            node["name"] =  f"workernode-{len(worker_nodes) + 1}"
            cpu_architecture = get_cpu_architecture(hostname)
            if cpu_architecture:
                node["cpu_architecture"] = cpu_architecture
            if args.verbose:
                print(f"Found {hostname} at {ip}, adding as workernode {node}")
            
            worker_nodes.append(node)

        if 'etcd' in hostname:
            if args.verbose:
                print(f"Adding {hostname} as etcd node")
            etcd_nodes.append(node["name"])
            node["etcd_member_name"] = f"etcd{len(etcd_nodes)}"


    with open(inventory_file, 'w') as file:
        for node in controlplane_nodes + worker_nodes:
            print(node)
            host = f"{node['name']} ansible_host={node['ip']}"
            if "etcd_member_name" in node:
                host += f" etcd_member_name={node['etcd_member_name']}"
            if "cpu_architecture" in node:
                host += f" host_architecture={node['cpu_architecture']}"
            file.write(host + '\n')

        # Create ansible groups
        file.write("\n[kube_control_plane]\n")
        for node in controlplane_nodes:
            file.write(node["name"] + '\n')

        file.write("\n[kube_node]\n")
        for node in worker_nodes:
            file.write(node["name"] + '\n')
        
        file.write("\n[etcd]\n")
        for hostname in etcd_nodes:
            file.write(hostname + '\n')

        file.write("\n[k8s_cluster:children]\n")
        file.write("kube_control_plane\nkube_node\n")

    if args.verbose:
        print("Generated inventory file:\n")

    if not args.quiet:
        with open(inventory_file, 'r') as file:
            print(file.read())

    if args.target_file:
        subprocess.run(['cp', inventory_file, args.target_file])
        if args.verbose:
            print(f"Created inventory file at {args.target_file}")

    subprocess.run(['rm', inventory_file])

if __name__ == "__main__":
    main()

