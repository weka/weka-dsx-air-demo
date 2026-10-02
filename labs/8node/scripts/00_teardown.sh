#!/usr/bin/env bash
# Destructive DSX Air lab reset, without a UUID check. Default: read-only plan. --apply removes WEKA containers
# and zeroes only the eight verified data disks. Root and swap disks are preserved.
set -Eeuo pipefail
umask 077
[[ $(id -un) == ubuntu && $(hostname -s) == WekaNode01 ]] || { echo 'Run as ubuntu on WekaNode01'; exit 1; }
mode="${1:---plan}"
[[ $# -le 1 && ( $mode == --plan || $mode == --apply ) ]] || { echo 'Usage: bash 00_teardown.sh [--plan|--apply]'; exit 1; }
opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
remote() { local n="$1"; shift; ssh "${opts[@]}" "ubuntu@192.168.200.$n" "$@"; }
logdir="$HOME/weka-reset-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$logdir"
exec > >(tee "$logdir/reset.log") 2>&1
trap 'echo "Reset stopped at line $LINENO. Retain logs; do not take a checkpoint of a partial reset."' ERR
echo 'DSX Air disposable lab reset: eight backends and two clients.'
echo 'Target: management IPs 192.168.200.11-18,21-22 in this simulation.'
echo 'No cluster UUID or cluster login required. --apply deletes cluster data.'
for n in 11 12 13 14 15 16 17 18 21 22; do
  remote "$n" "sudo -n bash -s -- $n" <<'REMOTE'
set -euo pipefail
n="$1"
if (( n <= 18 )); then expected=$(printf 'WekaNode%02d' "$((n-10))"); else expected=$(printf 'Client%02d' "$((n-20))"); fi
[[ $(hostname -s) == "$expected" ]]
command -v timeout >/dev/null
weka version | grep -Eq '^\*?[[:space:]]*5\.1\.34[[:space:]]*$'
psout=$(weka local ps --color disabled)
echo "$psout"
# Only known lab containers may be present. Never use local rm --all.
echo "$psout" | awk -v backend="$((n<=18))" 'NR==1{next} NF{if($1!="default" && !(backend==0 && $1=="client")) bad=1} END{exit bad}'
if (( n <= 18 )); then
  # WEKA may own the data controller via igb_uio; block device checks come later.
  lspci -nnk -d ::0108
  echo 'Data disk serial/size checks deferred until all containers are removed.'
fi
REMOTE
done
if [[ $mode == --plan ]]; then
  echo 'PLAN ONLY: unmount clients; stop all ten lab containers; remove only default/client; verify all eight data disks by serial, then zero them.'
  echo 'No cluster changes or disk writes made. Apply with: bash 00_teardown.sh --apply'
  exit 0
fi
# Unmount first; abort on a busy mount. No forced or lazy unmount.
for n in 21 22; do
  remote "$n" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
if mountpoint -q /mnt/weka; then
  [[ $(findmnt -n -o FSTYPE -T /mnt/weka) == wekafs ]]
  timeout 60 umount /mnt/weka
fi
# Remove any old persistence entry for the demo mount only.
if grep -Eq '^[^#].*[[:space:]]/mnt/weka[[:space:]]+wekafs[[:space:]]' /etc/fstab; then
  cp -a /etc/fstab "/etc/fstab.before-weka-reset-$(date +%s)"
  sed -i '\|^[^#].*[[:space:]]/mnt/weka[[:space:]]\+wekafs[[:space:]]|d' /etc/fstab
fi
REMOTE
done
# Stop all containers BEFORE removing any backend state or touching disks.
pids=()
for n in 11 12 13 14 15 16 17 18 21 22; do
  remote "$n" 'sudo -n bash -s' <<'REMOTE' &
set -euo pipefail
for c in default client; do
  line=$(weka local ps --color disabled | awk -v c="$c" '$1==c{print}')
  if [[ -n $line && $line == *Running* ]]; then
    timeout 120 weka local stop --force "$c"
  fi
done
weka local ps --color disabled | awk 'NR>1 && /Running/{bad=1} END{exit bad}'
REMOTE
  pids+=("$!")
done
failed=0
for pid in "${pids[@]}"; do if ! wait "$pid"; then failed=1; fi; done
[[ $failed == 0 ]] || { echo 'A container failed to stop. No disks zeroed.'; exit 1; }
for n in 11 12 13 14 15 16 17 18 21 22; do
  remote "$n" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
for c in default client; do
  if weka local ps --color disabled | awk -v c="$c" '$1==c{found=1} END{exit !found}'; then
    weka local rm --force "$c"
  fi
done
weka local ps --color disabled | awk 'NR>1 && NF{bad=1} END{exit bad}'
REMOTE
done
# Verify ALL eight returned disks before starting ANY disk wipe.
for n in 11 12 13 14 15 16 17 18; do
  remote "$n" "sudo -n bash -s -- $n" <<'REMOTE'
set -euo pipefail
n="$1"; expected=$(printf 'weka%02d' "$((n-10))")
udevadm settle --timeout=30
# Find by serial: Linux NVMe numbering can change after drivers return.
dev=''
for attempt in $(seq 1 15); do
  dev=$(lsblk -dn -p -o NAME,SERIAL | awk -v s="$expected" '$2==s{print $1}')
  [[ -n $dev ]] && break
  sleep 2
done
[[ -n $dev && $dev != *$'\n'* && -b $dev ]] || {
  echo "ERROR: expected disk $expected has not returned to Linux. No disk wipes started."; exit 1;
}
size=$(blockdev --getsize64 "$dev")
(( size > 40000000000 && size < 60000000000 ))
[[ -z $(lsblk -nr -o MOUNTPOINTS "$dev" | tr -d '[:space:]') ]]
[[ -z $(ls "/sys/class/block/${dev##*/}/holders") ]]
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$dev"
echo "VERIFIED: $expected $dev $size bytes"
REMOTE
done

# Whole-device zeroout, with a complete byte-counted dd fallback.
pids=()
for n in 11 12 13 14 15 16 17 18; do
  remote "$n" "sudo -n bash -s -- $n" <<'REMOTE' &
set -euo pipefail
n="$1"
expected=$(printf 'weka%02d' "$((n-10))")
dev=$(lsblk -dn -p -o NAME,SERIAL | awk -v s="$expected" '$2==s{print $1}')
[[ -n $dev && $dev != *$'\n'* && -b $dev ]]
[[ $(lsblk -dn -o SERIAL "$dev" | tr -d '[:space:]') == "$expected" ]]
[[ -z $(lsblk -nr -o MOUNTPOINTS "$dev" | tr -d '[:space:]') ]]
[[ -z $(ls "/sys/class/block/${dev##*/}/holders") ]]
size=$(blockdev --getsize64 "$dev")
(( size > 40000000000 && size < 60000000000 ))
echo "ZEROING $expected $dev $size bytes"
if ! blkdiscard --zeroout "$dev"; then
  dd if=/dev/zero of="$dev" bs=4M count="$size" iflag=count_bytes conv=fsync status=progress
fi
sync
blockdev --rereadpt "$dev"
# Read the WHOLE device and compare with zeros. A successful reset requires this.
cmp -n "$size" "$dev" /dev/zero
[[ -z $(wipefs --no-act --noheadings --output TYPE "$dev" | tr -d '[:space:]') ]]
echo "PASS: $expected entire data disk is zero; root and swap preserved."
REMOTE
  pids+=("$!")
done
failed=0
for pid in "${pids[@]}"; do if ! wait "$pid"; then failed=1; fi; done
[[ $failed == 0 ]] || { echo 'Disk reset incomplete. Do not take a checkpoint.'; exit 1; }
echo "RESET COMPLETE. Logs: $logdir"
echo 'Take the clean checkpoint in Air now, before running 01_create_cluster.sh.'
echo 'WEKA binaries, SSH keys, data network, packages, root disk and swap remain configured.'
