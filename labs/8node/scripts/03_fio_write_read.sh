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
for n in 21 22; do
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
for n in 21 22; do
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" "bash -s -- '$folder' $n" <<'REMOTE'
set -euo pipefail
folder="$1"; n="$2"
[[ $(findmnt -n -o FSTYPE -T /mnt/weka) == wekafs ]]
mkdir -p "$folder"
file="$folder/client$n.bin"
[[ ! -e $file ]]
echo "=== WRITE from $(hostname) to $file ==="
fio --name=weka-write --filename="$file" --rw=write --bs=1M --size=1G \
  --numjobs=1 --iodepth=8 --ioengine=libaio --direct=1 \
  --verify=crc32c --do_verify=0 --end_fsync=1 --group_reporting
REMOTE
done
for n in 21 22; do
  peer=$((43-n))
  ssh "${opts[@]}" "ubuntu@192.168.200.$n" "bash -s -- '$folder' $peer" <<'REMOTE'
set -euo pipefail
folder="$1"; peer="$2"; file="$folder/client$peer.bin"
[[ $(findmnt -n -o FSTYPE -T /mnt/weka) == wekafs ]]
[[ -f $file && $(stat -c %s "$file") == 1073741824 ]]
echo "=== READ and CRC32C VERIFY from $(hostname): $file ==="
fio --name=weka-read-verify --filename="$file" --rw=read --bs=1M --size=1G \
  --numjobs=1 --iodepth=8 --ioengine=libaio --direct=1 --allow_file_create=0 \
  --verify=crc32c --verify_fatal=1 --group_reporting
REMOTE
done
echo "PASS: both clients wrote 1 GiB; both files read and checksum-verified by the other client. Files: $folder; logs: $logs"
