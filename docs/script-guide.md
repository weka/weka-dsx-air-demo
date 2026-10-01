# Numbered script guide

Run scripts from the repository root on WekaNode01 or the Air OOB server, with Python 3 and OpenSSH installed. Choose one inventory with `--lab 5node` or `--lab 8node`.

| Script | Default behavior | Changes made |
| --- | --- | --- |
| 0_preflight.sh | Collects host/IP/memory/disk/software evidence over management SSH | None |
| 1_setup_data_network.sh | Prints the exact host Netplan snippets | With `--apply`, writes eth1 config and calls netplan apply |
| 2_validate_lab.sh | Collects backend and client health/mount output | None |
| 3_fio_smoke_test.sh | Shows the test commands | With `--run`, creates test files on client WEKA mounts |

These are functional helpers, not a WEKA software installer. WEKA provisioning is a separate reviewed task. The original five-node rebuild is under reference/5node as text. Eight-node cluster initialization is pending.

## Authentication

SSH uses management IPs, Ubuntu user `ubuntu`, normal host-key verification, and your configured key/agent or an interactive password. Each command uses a 10-second SSH connection timeout. Remote privileged steps require passwordless `sudo -n`; a failure stops the step rather than waiting for an unread sudo password. Verify the intended host key when first connecting. Do not use blanket host-key-check disabling.

## Applying data-network changes

Before `--apply`, back up the current Netplan files and inspect all effective configuration. The helper preserves the text of existing files, writes only a new eth1 fragment, and rejects an existing eth1 fragment with different contents. However, `netplan apply` re-applies the merged host configuration and may disrupt access if existing files conflict. Keep Air consoles open and do not apply to a working lab without reviewing the merged configuration.

The generated fragment does not configure the switch. Confirm bridge membership and a 9000-byte path MTU first. On an established lab, use preflight/validation rather than applying networking again.

## Validation limitations

The validation script returns failures for failed remote commands or missing wekafs mounts. It prints WEKA status/drive/fs/alerts but does not parse the status headline to certify counts/protection. Review those values against the lab guide before calling the cluster healthy. Read-only checks do not resolve licensing or alerts.

## fio

The smoke-test helper checks for the `wekafs` filesystem and an installed fio binary before writing. It runs both clients sequentially, roughly 30 seconds each, using separate directories and files. It is a functionality test, not aggregate production benchmarking. It writes roughly 4 GiB of allocated files per client. Confirm capacity before running. No test files are removed automatically.
