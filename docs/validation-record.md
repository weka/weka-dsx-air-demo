# Validation record

Snapshot: October 1, 2026. Evidence was provided through console output and Air screenshots; the repository author did not access the VMs.

| Item | Five-node reference | Eight-node lab |
| --- | --- | --- |
| Import | Existing lab active | Imported successfully |
| Boot | Running | Blocked by memory quota |
| WEKA release | 5.1.0.605 active | Not installed/verified in new VMs |
| Backends/drives | 5 UP / 5 UP | Pending |
| Protection | 3+2 fully protected | Pending |
| I/O / clients | STARTED / 2 connected | Pending |
| Alerts/license | 3 active alerts / Unlicensed | Pending |
| fio excerpt | WRITE 63.4 MiB/s, ~30.3 s | Pending |
| Shared-file test | Not captured | Pending |
| Jumbo ICMP test | Not captured | Pending |
| External OOB SSH | Both tested Mac keys rejected | Pending |
| Checkpoint recovery | Not confirmed | Not confirmed |

## Commissioning evidence to add

Record date, tester, active image/version, switch bridge/VLAN/MTU, all node version/disk checks, actual container IDs, protection/hot-spare settings, filesystem capacity, client mounts, cross-client file output, fio commands and complete outputs, alerts, licensing, and successful checkpoint restore. Do not replace pending results with five-node values.
