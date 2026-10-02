#!/usr/bin/env bash
# Optional fallback if WEKA HTTPS listens only on the data IP.
set -Eeuo pipefail
[[ $(hostname -s) == WekaNode01 ]] || { echo 'Run on WekaNode01'; exit 1; }
curl -k -sS -o /dev/null --connect-timeout 5 --max-time 15 https://10.200.100.11:14000/
sudo -n true
if ! command -v socat >/dev/null; then
  sudo -n apt-get update
  sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y socat
fi
if ! sudo -n systemctl is-active --quiet weka-gui-mgmt-relay && [[ -n $(ss -H -ltn 'sport = :14001') ]]; then
  echo 'Port 14001 already in use by another service; stopping.'; exit 1
fi
sudo -n tee /etc/systemd/system/weka-gui-mgmt-relay.service >/dev/null <<'UNIT'
[Unit]
Description=WEKA data HTTPS to management TCP relay
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/socat TCP4-LISTEN:14001,bind=192.168.200.11,reuseaddr,fork TCP4:10.200.100.11:14000
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT
sudo -n systemctl daemon-reload
sudo -n systemctl enable weka-gui-mgmt-relay
sudo -n systemctl restart weka-gui-mgmt-relay
sleep 2
sudo -n systemctl is-active --quiet weka-gui-mgmt-relay
curl -k -sS -o /dev/null --connect-timeout 5 --max-time 15 https://192.168.200.11:14001/
echo 'On OOB, run: BACKEND_PORT=14001 bash 04_oob_gui_service.sh'
