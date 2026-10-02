# Script guide

Scripts live in labs/8node/scripts. Run as ubuntu with passwordless sudo.

| Script | Host | Purpose |
|---|---|---|
| 00_teardown.sh | WekaNode01 | Plan by default; --apply removes known lab containers and zeroes all eight verified data disks. No UUID/login requirement. |
| 01_create_cluster.sh | WekaNode01 | Create an unconfigured cluster and 80 GiB filesystem; permits active swap. |
| 02_mount_clients.sh | WekaNode01 | Mount both clients over UDP. |
| 03_fio_write_read.sh | WekaNode01 | Two writes and cross-client verified reads. |
| 04_unmount_clients.sh | WekaNode01 | Unmount both clients; optional --stop-client. |
| 05_oob_gui_service.sh | oob-mgmt-server | Install persistent HTTPS TCP relay on port 14000. |
| 05b_node01_gui_relay.sh | WekaNode01 | Optional management-to-data relay on port 14001. |

Follow the [lab guide](../labs/8node/README.md). Scripts are intentionally separated for demonstrations and diagnosis. Only reset uses --apply; creation is not a general resume command. Never continue past a failed preflight without inspecting its cause.
