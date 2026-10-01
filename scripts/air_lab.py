#!/usr/bin/env python3
"""Air helpers: no WEKA provisioning or disk wiping."""
import argparse
import ipaddress
import json
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def remote(host, command, *, stdin=None):
    target = f"{host['ssh_user']}@{host['management_ip']}"
    print(f"\n--- {host['name']} ({target}) ---", flush=True)
    result = subprocess.run(['ssh', '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=15',
                             '-o', 'ServerAliveCountMax=2', target, command],
                            input=stdin, text=True, check=False)
    return result.returncode == 0

def load(lab):
    data = json.loads((ROOT / 'labs' / lab / 'inventory.json').read_text())
    for h in data['hosts']:
        ipaddress.IPv4Address(h['management_ip'])
        ipaddress.IPv4Address(h['data_ip'])
        if h['ssh_user'] != 'ubuntu' or h['interface'] != 'eth1' or h['mtu'] != 9000:
            raise ValueError('Unexpected host access/network setting')
    return data

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['preflight', 'network', 'validate', 'fio'])
    parser.add_argument('--lab', choices=['8node'], default='8node')
    parser.add_argument('--apply', action='store_true', help='Apply network fragments; requires sudo -n')
    parser.add_argument('--run', action='store_true', help='Run fio on mounted client filesystems')
    args = parser.parse_args()
    if args.apply and args.action != 'network':
        parser.error('--apply is only valid for network')
    if args.run and args.action != 'fio':
        parser.error('--run is only valid for fio')
    lab = load(args.lab)
    hosts = lab['hosts']
    failed = False
    if args.action == 'preflight':
        command = "set -e; hostname; ip -br a; free -h; lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS; command -v weka && weka version"
        for h in hosts:
            failed |= not remote(h, command)
    elif args.action == 'network':
        for h in hosts:
            fragment = (ROOT / 'labs' / args.lab / 'config' / 'netplan' / f"{h['name']}.yaml").read_text()
            print(f"\n{h['name']} eth1 configuration:\n{fragment}", flush=True)
            if not args.apply:
                continue
            # Only the newly authored file is touched. Merged netplan applies to all interfaces.
            script = """set -euo pipefail
command -v netplan >/dev/null
install -d -m 755 /etc/netplan
cfg=/etc/netplan/70-weka-air-data.yaml
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<'WEKA_NETPLAN'
""" + fragment + """WEKA_NETPLAN
if [[ -e "$cfg" ]] && ! cmp -s "$tmp" "$cfg"; then
  echo "Existing $cfg differs; review it in the console before applying." >&2
  exit 1
fi
install -m 600 "$tmp" "$cfg"
netplan generate
netplan apply
ip -br a
"""
            if not remote(h, 'sudo -n bash -s', stdin=script):
                return 1
        if not args.apply:
            print('Preview only. Review merged Netplan and switch forwarding before using --apply.')
    elif args.action == 'validate':
        lead = next(h for h in hosts if h['name'] == 'WekaNode01')
        failed |= not remote(lead, 'set -e; weka status; weka cluster drive; weka fs; weka alerts')
        iplist = ' '.join(shlex.quote(h['data_ip']) for h in hosts)
        failed |= not remote(lead, f'set -e; for ip in {iplist}; do ping -I eth1 -c 2 -W 2 "$ip"; done')
        for h in hosts:
            if h['role'] == 'backend':
                failed |= not remote(h, 'sudo -n weka local ps')
            else:
                failed |= not remote(h, "set -e; findmnt -T /mnt/weka; df -hT /mnt/weka; test \"$(findmnt -n -o FSTYPE -T /mnt/weka)\" = wekafs")
        print('Review printed backend/drive counts, I/O state, protection, licensing and alerts against the guide.')
    else:
        for h in hosts:
            if h['role'] != 'client':
                continue
            dirname = '/mnt/weka/air-lab-validation/fio-' + h['name'].lower()
            command = ("set -e; test \"$(findmnt -n -o FSTYPE -T /mnt/weka)\" = wekafs; "
                       "command -v fio >/dev/null; mkdir -p " + shlex.quote(dirname) +
                       '; fio --name=air-' + h['name'].lower() + '-write --directory=' + shlex.quote(dirname) +
                       ' --rw=write --bs=1M --size=2G --numjobs=2 --iodepth=8 --ioengine=libaio'
                       ' --direct=1 --runtime=30 --time_based --group_reporting')
            if args.run:
                print('Allow approximately 30 seconds plus setup/flush time per client.', flush=True)
                if not remote(h, command):
                    return 1
            else:
                print(f"\n{h['name']} preview:\n{command}")
        if not args.run:
            print('Preview only. Confirm both wekafs mounts and free space before adding --run.')
    return 1 if failed else 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
