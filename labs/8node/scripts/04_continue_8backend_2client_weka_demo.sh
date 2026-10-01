#!/usr/bin/env bash
# Fresh DSX Air lab only: eight backends and two clients, WEKA 5.1.34.
# Run as ubuntu on WekaNode01. Installation and data network must already work.
# Removes only initial default STEM containers. Adds nvme0n1 to WEKA;
# initializes blank nvme1n1 as swap. Refuses to rebuild an existing cluster.
set -Eeuo pipefail
umask 077
CLUSTER_NAME="${CLUSTER_NAME:-WekaDSXAirDemo8Node}"
FS_NAME="${FS_NAME:-default}"
FS_GROUP="${FS_GROUP:-group1}"
FS_SIZE="${FS_SIZE:-80GiB}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/weka}"
RUN_FIO="${RUN_FIO:-1}"
BACKENDS=(WekaNode01 WekaNode02 WekaNode03 WekaNode04 WekaNode05 WekaNode06 WekaNode07 WekaNode08)
BACKEND_IPS=(10.200.100.11 10.200.100.12 10.200.100.13 10.200.100.14 10.200.100.15 10.200.100.16 10.200.100.17 10.200.100.18)
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
[[ $(id -un) == ubuntu && $(hostname -s) == WekaNode01 ]] || {
  echo 'Run as ubuntu on WekaNode01.' >&2; exit 1;
}
for value in "$CLUSTER_NAME" "$FS_NAME" "$FS_GROUP" "$FS_SIZE"; do
  [[ $value =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid configuration value'; exit 1; }
done
[[ $MOUNT_POINT =~ ^/[A-Za-z0-9_./-]+$ && $MOUNT_POINT != / && $MOUNT_POINT != *..* ]] || exit 1
[[ $RUN_FIO == 0 || $RUN_FIO == 1 ]] || exit 1
LOG_DIR="$HOME/weka-8node-build-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
exec > >(tee "$LOG_DIR/build.log") 2>&1
trap 'rc=$?; echo "Stopped at line $LINENO (exit $rc). Log: $LOG_DIR/build.log"; echo "Do not run teardown or blindly rerun; inspect the failed phase first."; exit "$rc"' ERR
sudo -n true
command -v python3 >/dev/null
remote() { local n="$1"; shift; ssh "${SSH_OPTS[@]}" "ubuntu@192.168.200.$n" "$@"; }

echo '=== Continue the existing eight-node cluster; no container reset ==='
sudo -n weka status --color disabled > "$LOG_DIR/before-resume.txt"
cat "$LOG_DIR/before-resume.txt"
grep -Fq 'ba6d7699-3df0-4ada-a00e-29855bb03df1' "$LOG_DIR/before-resume.txt"
grep -Eq '8 backend containers UP, 0 drives UP' "$LOG_DIR/before-resume.txt"
grep -Eq 'io status:[[:space:]]+STOPPED' "$LOG_DIR/before-resume.txt"
sudo -n weka cluster container
# Read actual IDs from the cluster instead of assuming IDs 0 through 7.
sudo -n weka cluster container --format csv --output id,hostname > "$LOG_DIR/containers.csv"
python3 - "$LOG_DIR/containers.csv" > "$LOG_DIR/container-map.tsv" <<'PY'
import csv, sys
with open(sys.argv[1], newline='') as f:
    reader = csv.DictReader(f)
    rows = [{k.strip().lower(): v.strip() for k, v in row.items()} for row in reader]
expected = [f'WekaNode{i:02d}' for i in range(1, 9)]
mapping = {}
for row in rows:
    name = row.get('hostname', '')
    ident = row.get('id', row.get('container id', ''))
    if name in mapping or name not in expected or not ident.isdigit():
        raise SystemExit(f'Unexpected container row: {row}')
    mapping[name] = ident
if set(mapping) != set(expected) or len(set(mapping.values())) != 8:
    raise SystemExit('Expected eight unique backend containers; stopping before adding drives.')
for name in expected:
    print(name, mapping[name], sep='\t')
PY
echo '=== Add the verified WEKA data disk on each backend ==='
while IFS=$'\t' read -r node ident; do
  echo "Adding /dev/nvme0n1 on $node, container $ident"
  sudo -n weka cluster drive add "$ident" /dev/nvme0n1
done < "$LOG_DIR/container-map.tsv"
sudo -n weka cluster update --data-drives=5 --parity-drives=2
sudo -n weka cluster hot-spare 1
sudo -n weka cluster start-io

echo '=== Wait for eight backends and eight drives to be UP ==='
ready=0
for attempt in $(seq 1 120); do
  if sudo -n weka status --color disabled > "$LOG_DIR/status.txt" 2>&1; then
    if grep -Eq 'status:[[:space:]]+OK.*8 backend containers UP.*8 drives UP' "$LOG_DIR/status.txt" &&
       grep -Eq 'io status:[[:space:]]+STARTED' "$LOG_DIR/status.txt"; then
      ready=1; break
    fi
  fi
  if (( attempt % 10 == 0 )); then cat "$LOG_DIR/status.txt"; fi
  sleep 5
done
cat "$LOG_DIR/status.txt"
[[ $ready == 1 ]]

echo '=== Create filesystem ==='
sudo -n weka fs group create "$FS_GROUP"
sudo -n weka fs create "$FS_NAME" "$FS_GROUP" "$FS_SIZE"
sudo -n weka fs

echo '=== Mount the filesystem on both clients using UDP ==='
for n in 21 22; do
  remote "$n" "sudo -n bash -s -- $n $FS_NAME $MOUNT_POINT $RUN_FIO" <<'REMOTE'
set -euo pipefail
n="$1"; fs="$2"; mp="$3"; run_fio="$4"
if ! command -v fio >/dev/null; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y fio
fi
# These clients were checked as initial STEM containers during preflight.
if weka local ps --color disabled | grep -Eq '^default[[:space:]]+65535[[:space:]]+Running[[:space:]]+STEM mode'; then
  weka local stop default
fi
if weka local ps --color disabled | grep -Eq "^default[[:space:]]"; then
  weka local rm --force default
fi
mkdir -p "$mp"
if mountpoint -q "$mp"; then echo "Already mounted: $mp"; exit 1; fi
mount -t wekafs -o "net=udp,num_cores=0,mgmt_ip=10.200.100.$n" "10.200.100.11/$fs" "$mp"
# Write access for ubuntu, without making the whole filesystem world writable.
chown ubuntu:ubuntu "$mp"
chmod 0755 "$mp"
findmnt -T "$mp"
df -h "$mp"
weka local ps
if [[ $run_fio == 1 ]]; then
  testdir="$mp/fio-smoke-$(hostname)-$(date +%Y%m%d-%H%M%S)"
  install -d -o ubuntu -g ubuntu "$testdir"
  sudo -u ubuntu fio --name="weka-client-write-$(hostname)" \
    --directory="$testdir" --rw=write --bs=1M --size=1G \
    --numjobs=2 --iodepth=8 --ioengine=libaio --direct=1 \
    --runtime=30 --time_based --group_reporting
fi
REMOTE
done
echo '=== Final cluster status ==='
sudo -n weka status
sudo -n weka cluster container
sudo -n weka cluster drive
sudo -n weka alerts
echo "Build finished. Logs: $LOG_DIR"
echo 'Client mounts are active for this session; reboot persistence is not configured.'
