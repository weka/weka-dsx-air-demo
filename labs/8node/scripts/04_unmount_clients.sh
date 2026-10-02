#!/usr/bin/env bash
# Run as ubuntu on WekaNode01. Unmount both clients; optionally stop only
# their named client containers. No backend, filesystem or disk deletion.
set -Eeuo pipefail
[[ $(id -un) == ubuntu && $(hostname -s) == WekaNode01 ]] || {
  echo 'Run as ubuntu on WekaNode01.' >&2; exit 1;
}
mode="${1:---unmount-only}"
[[ $# -le 1 && ( $mode == --unmount-only || $mode == --stop-client ) ]] || {
  echo 'Usage: bash 05_unmount_clients.sh [--unmount-only|--stop-client]'; exit 1;
}
MOUNT_POINT="${MOUNT_POINT:-/mnt/weka}"
[[ $MOUNT_POINT =~ ^/[A-Za-z0-9_./-]+$ && $MOUNT_POINT != / && $MOUNT_POINT != *..* ]] || exit 1
opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
# Preflight BOTH hosts before unmounting either one.
for n in 21 22; do
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" "sudo -n bash -s -- $n $MOUNT_POINT" <<'REMOTE'
set -euo pipefail
n="$1"; mp="$2"
[[ $(hostname -s) == "$(printf 'Client%02d' "$((n-20))")" ]]
command -v timeout >/dev/null
if mountpoint -q "$mp"; then
  [[ $(findmnt -n -o FSTYPE --mountpoint "$mp") == wekafs ]] || {
    echo "Refusing: $mp is not a WEKA mount."; exit 1;
  }
  findmnt --mountpoint "$mp"
fi
REMOTE
done
for n in 21 22; do
  echo "=== Unmount Client$((n-20)) / 192.168.200.$n ==="
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" "sudo -n bash -s -- $MOUNT_POINT" <<'REMOTE'
set -euo pipefail
mp="$1"
if mountpoint -q "$mp"; then
  [[ $(findmnt -n -o FSTYPE --mountpoint "$mp") == wekafs ]]
  if ! timeout 60 umount "$mp"; then
    echo "Unmount failed or timed out on $(hostname). No forced/lazy unmount attempted."
    echo "Leave directories under $mp, stop jobs using it, then rerun."
    command -v fuser >/dev/null && fuser -vm "$mp" || true
    exit 1
  fi
fi
if mountpoint -q "$mp"; then echo "ERROR: $mp remains mounted"; exit 1; fi
echo "PASS: $(hostname) $mp is unmounted."
REMOTE
done
if [[ $mode == --stop-client ]]; then
  for n in 21 22; do
    ssh "${opts[@]}" "ubuntu@192.168.200.$n" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
line=$(weka local ps --color disabled | awk '$1=="client"{print}')
if [[ $line == *Running* ]]; then
  timeout 120 weka local stop client
fi
weka local ps --color disabled
weka local ps --color disabled | awk '$1=="client" && /Running/{bad=1} END{exit bad}'
REMOTE
  done
fi
echo 'UNMOUNT COMPLETE: both clients are unmounted. Backend cluster and stored data retained.'
echo 'Mount persistence entries, if any, are unchanged.'
