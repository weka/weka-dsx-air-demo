#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $(id -un) == ubuntu && $(hostname -s) == WekaNode01 ]] || { echo 'Run as ubuntu on WekaNode01'; exit 1; }
opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
status=$(weka status --color disabled)
echo "$status"
grep -Eq 'status:[[:space:]]+OK.*8 backend containers UP.*8 drives UP' <<< "$status"
grep -Eq 'io status:[[:space:]]+STARTED' <<< "$status"
weka fs
for n in 21 22; do
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" "sudo -n bash -s -- $n" <<'REMOTE'
set -euo pipefail
n="$1"; mp=/mnt/weka
hostname
ip -4 -o addr show eth1 | grep -F "10.200.100.$n/24"
if mountpoint -q "$mp"; then
  [[ $(findmnt -n -o FSTYPE -T "$mp") == wekafs ]]
  [[ $(findmnt -n -o SOURCE -T "$mp") == 10.200.100.11/default ]]
else
  # Remove only an initial installer STEM container; refuse any other default.
  line=$(weka local ps --color disabled | awk '$1=="default"{print}')
  if [[ -n $line ]]; then
    if grep -Eq '^default[[:space:]]+65535[[:space:]]+Running[[:space:]]+STEM mode' <<< "$line"; then
      weka local stop default
    elif ! grep -Eq '^default[[:space:]]+Stopped[[:space:]]+UNKNOWN' <<< "$line"; then
      echo 'Unexpected default container; stopping without removing it.'; exit 1
    fi
    weka local rm --force default
  fi
  mkdir -p "$mp"
  mount -t wekafs -o "net=udp,num_cores=0,mgmt_ip=10.200.100.$n" 10.200.100.11/default "$mp"
fi
chown ubuntu:ubuntu "$mp"
chmod 0755 "$mp"
findmnt -T "$mp"
df -hT "$mp"
weka local ps
REMOTE
done
weka status
echo 'Both clients mounted. Session mounts only; next: bash 03_fio_write_read.sh'
