#!/usr/bin/env bash
# 1 GiB sequential write on each client; read/CRC32C verify from the OTHER client.
set -Eeuo pipefail
umask 077
[[ $(id -un) == ubuntu && $(hostname -s) == WekaNode01 ]] || { echo 'Run as ubuntu on WekaNode01'; exit 1; }
opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
run="$(date -u +%Y%m%dT%H%M%SZ)-$$"
logs="$HOME/weka-fio-$run"; mkdir -p "$logs"
exec > >(tee "$logs/fio.log") 2>&1
folder="/mnt/weka/fio-verify-$run"
for n in 11 19 20; do
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
[[ $(findmnt -n -o FSTYPE -T /mnt/weka) == wekafs ]]
if ! command -v fio >/dev/null; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y fio
fi
fio --version
REMOTE
done
for n in 19 20; do
   ssh 192.168.200.$n /usr/bin/fio --server --daemonize=/tmp/fio.pid
done
/usr/bin/fio --client=/home/ubuntu/client /home/ubuntu/job-file/01-write
/usr/bin/fio --client=/home/ubuntu/client /home/ubuntu/job-file/01-read
echo "PASS: both clients wrote 1 GiB; both files read and checksum-verified by the other client. Files: $folder; logs: $logs"
