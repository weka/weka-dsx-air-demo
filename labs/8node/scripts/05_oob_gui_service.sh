#!/usr/bin/env bash
# Run on oob-mgmt-server as ubuntu. TCP relay preserves WEKA's HTTPS end to end.
set -Eeuo pipefail
[[ ${HOSTNAME,,} == oob-mgmt-server ]] || { echo 'Run on oob-mgmt-server, not WekaNode01.'; exit 1; }
backend_port="${BACKEND_PORT:-14000}"
[[ $backend_port == 14000 || $backend_port == 14001 ]] || exit 1
sudo -n true
# Check backend before changing the OOB server.
curl -k -sS -o /dev/null --connect-timeout 5 --max-time 15 "https://192.168.200.11:$backend_port/" || {
  echo 'Backend HTTPS unreachable from OOB. Run 05b_node01_gui_relay.sh on WekaNode01,'
  echo 'then retry this script on OOB with BACKEND_PORT=14001.'; exit 1;
}
if ! command -v socat >/dev/null; then
  sudo -n apt-get update
  sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y socat
fi
if ! sudo -n systemctl is-active --quiet weka-gui-relay && [[ -n $(ss -H -ltn 'sport = :14000') ]]; then
  echo 'Port 14000 already in use by another service; stopping.'; exit 1
fi
sudo -n tee /etc/systemd/system/weka-gui-relay.service >/dev/null <<UNIT
[Unit]
Description=DSX Air WEKA HTTPS TCP relay
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/socat TCP6-LISTEN:14000,ipv6only=0,reuseaddr,fork TCP4:192.168.200.11:$backend_port
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT
sudo -n systemctl daemon-reload
sudo -n systemctl enable weka-gui-relay
sudo -n systemctl restart weka-gui-relay
sleep 2
sudo -n systemctl is-active --quiet weka-gui-relay
curl -k -sS -o /dev/null --connect-timeout 5 --max-time 15 https://127.0.0.1:14000/
echo 'Relay ready: OOB port 14000 -> WekaNode01 HTTPS.'
echo 'Air: Services > New Service > Name weka-gui > Interface oob-mgmt-server:eth0 > HTTPS > Service Port 14000.'
echo 'Open the HTTPS URL assigned by Air; its external port can differ from 14000.'
