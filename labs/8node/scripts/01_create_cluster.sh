#!/usr/bin/env bash
# Fresh DSX Air lab only: eight backends and two clients, WEKA 5.1.34.
# Run as ubuntu on WekaNode01. Installation and data network must already work.
# Removes only initial default STEM containers. Adds nvme0n1 to WEKA;
# initializes blank nvme1n1 as swap. Refuses to rebuild an existing cluster.
set +x
set -Eeuo pipefail
umask 077
WEKA_ADMIN_PASSWORD="${WEKA_ADMIN_PASSWORD:-Weka.io123}"
CLUSTER_NAME="${CLUSTER_NAME:-WekaDSXAirDemo8Node}"
FS_NAME="${FS_NAME:-default}"
FS_GROUP="${FS_GROUP:-group1}"
FS_SIZE="${FS_SIZE:-80GiB}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/weka}"
RUN_FIO=0
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
# Preserve the terminal output so credentials are not copied into build.log.
exec 3>&1
exec > >(tee "$LOG_DIR/build.log") 2>&1
trap 'rc=$?; echo "Stopped at line $LINENO (exit $rc). Log: $LOG_DIR/build.log"; echo "Do not run teardown or blindly rerun; inspect the failed phase first."; exit "$rc"' ERR
sudo -n true
command -v python3 >/dev/null
remote() { local n="$1"; shift; ssh "${SSH_OPTS[@]}" "ubuntu@192.168.200.$n" "$@"; }

echo '=== Preflight ALL hosts before making changes ==='
for n in 11 12 13 14 15 16 17 18 21 22; do
  remote "$n" "sudo -n bash -s -- $n" <<'REMOTE'
set -euo pipefail
n="$1"
hostname
weka version | grep -Eq '^\*?[[:space:]]*5\.1\.34[[:space:]]*$'
ip -4 -o addr show eth1 | grep -F "10.200.100.$n/24"
[[ $(cat /sys/class/net/eth1/mtu) == 9000 ]]
if weka status >/dev/null 2>&1; then
  echo 'Existing cluster detected; refusing fresh build.' >&2; exit 1
fi
# A stopped initial container has a blank ID. Do not rely on ID 65535 alone.
weka local ps --color disabled | awk '
  NR==1 {next}
  NF==0 {next}
  {count++; if ($1 != "default") bad=1;
   if (!($2=="65535" && $3=="Running" && $4=="STEM" && $5=="mode") &&
       !($2=="Stopped" && $3=="UNKNOWN")) bad=1}
  END {if (count > 1 || bad) exit 1}' || {
    weka local ps; echo 'Unexpected container state; refusing removal.' >&2; exit 1;
  }
if (( n <= 18 )); then
  [[ $(nproc) -ge 4 ]]
  for pair in "nvme0n1:weka$(printf '%02d' "$((n-10))")" "nvme1n1:swap$(printf '%02d' "$((n-10))")"; do
    dev="/dev/${pair%%:*}"; expected="${pair#*:}"
    [[ -b $dev ]]
    serial=$(lsblk -dn -o SERIAL "$dev" | tr -d '[:space:]')
    [[ $serial == "$expected" ]] || { echo "Unexpected serial on $dev: $serial"; exit 1; }
    [[ $(lsblk -nr -o NAME "$dev" | wc -l) -eq 1 ]]
    if [[ $dev == /dev/nvme0n1 ]]; then
    [[ -z $(lsblk -dn -o MOUNTPOINTS "$dev" | tr -d '[:space:]') ]]
    fi
    types=$(wipefs --no-act --noheadings --output TYPE "$dev" | tr -d '[:space:]')
    if [[ $dev == /dev/nvme0n1 ]]; then
      [[ -z $types ]] || { echo "Data disk has signatures: $types"; exit 1; }
      size=$(blockdev --getsize64 "$dev")
      (( size > 40000000000 && size < 60000000000 ))
    else
      [[ -z $types || $types == swap ]] || { echo "Unexpected swap disk signature: $types"; exit 1; }
    fi
  done
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL /dev/nvme0n1 /dev/nvme1n1
fi
REMOTE
done
for ip in "${BACKEND_IPS[@]:1}" 10.200.100.21 10.200.100.22; do
  ping -I eth1 -c 1 -W 3 -M do -s 8972 "$ip"
done

echo '=== Configure backend swap and UDP containers ==='
for n in 11 12 13 14 15 16 17 18; do
  echo "===== Backend 192.168.200.$n ====="
  remote "$n" "sudo -n bash -s -- $n" <<'REMOTE'
set -euo pipefail
n="$1"
if [[ -z $(blkid -s TYPE -o value /dev/nvme1n1 || true) ]]; then
  mkswap /dev/nvme1n1
fi
uuid=$(blkid -s UUID -o value /dev/nvme1n1)
[[ -n $uuid ]]
if ! swapon --noheadings --show=NAME | grep -Fxq /dev/nvme1n1; then
  swapon /dev/nvme1n1
fi
if ! grep -Fq "UUID=$uuid" /etc/fstab; then
  cp -a /etc/fstab "/etc/fstab.before-weka-$(date +%Y%m%d-%H%M%S)"
  printf 'UUID=%s none swap sw 0 0\n' "$uuid" >> /etc/fstab
fi
if weka local ps --color disabled | grep -Eq '^default[[:space:]]+65535[[:space:]]+Running[[:space:]]+STEM mode'; then
  weka local stop default
fi
if weka local ps --color disabled | grep -Eq "^default[[:space:]]"; then
  weka local rm --force default
fi
weka local setup container --name default --base-port 14000 \
  --cores 3 --core-ids 1,2,3 --memory 4GiB \
  --drives-dedicated-cores 1 --compute-dedicated-cores 1 \
  --frontend-dedicated-cores 1 --failure-domain "fd$((n-10))" \
  --management-ips "10.200.100.$n" --net udp --no-start
weka local start default
ready=0
for attempt in $(seq 1 60); do
  if weka local ps --color disabled | grep -Eq '^default[[:space:]]+65535[[:space:]]+Running[[:space:]]+STEM mode'; then
    ready=1; break
  fi
  sleep 3
done
weka local ps
[[ $ready == 1 ]]
REMOTE
done

echo '=== Create eight-backend cluster ==='
HOST_IPS=$(IFS=,; echo "${BACKEND_IPS[*]/%/:14000}")
sudo -n weka cluster add "${BACKENDS[@]}" --host-ips="$HOST_IPS"
echo '=== Set admin password and authenticate ==='
# A newly created cluster starts with admin/admin. Wait for its login endpoint.
authenticated=0
for attempt in $(seq 1 30); do
  if sudo -n weka user login admin admin >/dev/null 2>&1; then
    authenticated=1; break
  fi
  sleep 2
done
[[ $authenticated == 1 ]] || { echo 'Initial admin login failed; inspect the new cluster before continuing.'; exit 1; }
if ! sudo -n weka user passwd --username admin --current-password admin "$WEKA_ADMIN_PASSWORD" >/dev/null 2>&1; then
  echo 'Admin password change failed; inspect the new cluster before continuing.'; exit 1
fi
# Root executes cluster setup; ubuntu runs the subsequent demo scripts.
if ! sudo -n weka user login admin "$WEKA_ADMIN_PASSWORD" >/dev/null 2>&1 ||
   ! weka user login admin "$WEKA_ADMIN_PASSWORD" >/dev/null 2>&1; then
  echo 'Password changed, but login failed. Log in with the configured new password before continuing.'; exit 1
fi
echo 'Admin password updated; root and ubuntu CLI profiles authenticated.'
sudo -n weka cluster update --cluster-name "$CLUSTER_NAME"
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

echo '=== Final backend validation ==='
sudo -n weka status
sudo -n weka cluster drive
sudo -n weka fs
echo "Cluster creation finished. Logs: $LOG_DIR"
echo 'Next: bash 02_mount_clients.sh'
printf '\nWEKA GUI credentials\nUsername: admin\nPassword: %s\nOpen the HTTPS URL assigned to weka-gui in Air Services.\n' "$WEKA_ADMIN_PASSWORD" >&3
