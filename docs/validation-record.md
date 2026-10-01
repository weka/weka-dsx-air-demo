# Validation record

Snapshot: October 1, 2026, approximately 08:35 Pacific. Source: supplied terminal output and Air screenshots. The author did not directly access the VMs.

| Check | Five-node reference | Eight-node lab |
| --- | --- | --- |
| Import / boot | Existing simulation running | Imported and booted after quota increase |
| WEKA | 5.1.0.605 | 5.1.34 on all ten hosts |
| Backends / drives | 5 UP / 5 UP | 8 UP / 8 UP; all disks ACTIVE, attachment OK |
| Protection | 3+2 fully protected | 5+2 fully protected |
| Hot spare | 1 failure domain | 1 failure domain, 28.12 GiB |
| Drive storage | 95.17 GiB usable total | 198.56 GiB usable total; 118.56 GiB unprovisioned |
| Filesystem | default, 20 GiB reference | default, group1, 80 GiB |
| I/O / clients | STARTED / 2 connected | STARTED; 24 I/O nodes UP, 6 buckets UP; 2 clients |
| Mounts | Reported working | Both /mnt/weka mounts, wekafs, client containers Running/Ready |
| fio write | 63.4 MiB/s excerpt | Client01 76.1 MiB/s / 30.222 s; Client02 74.1 MiB/s / 30.115 s; both err=0 |
| Switch | Not fully captured | Cumulus 5.16.1; br_default, untagged VLAN 100, 10 data ports, MTU 9000 |
| Jumbo pings | Not captured | Node01 to seven other backends and both clients, zero packet loss |
| License / alerts | Unlicensed / 3 alerts | Unlicensed / 5 alerts |
| Internal SSH / sudo | Used by reference scripts | Ubuntu key and sudo -n verified on all ten hosts |
| External Mac SSH | Tested keys rejected | Not validated |
| Shared-file checksum | Not captured | Guided test supplied; result not captured |
| Reboot / checkpoint restore | Not confirmed | Not confirmed; mounts are temporary |

Eight-node UUID: `ba6d7699-3df0-4ada-a00e-29855bb03df1`. Backend container IDs 0–7, client IDs 8–9. Each data disk reports 44.70 GiB. Configured backend resources were 3 cores / 4 GiB; the displayed UDP container CORES column was 0. Do not reinterpret that display as a measured process allocation.

## Alerts and sizing

Both clients have 8 GiB RAM and subsequently reported about 2.1 GiB available against the 3000 MB alert threshold. Five alerts comprise two AvailableMemory instances plus AdminDefaultPassword, NoClusterLicense, and SystemDefinedTLS. The proposal to increase both clients to 16 GiB has not been implemented. No alerts were muted as part of commissioning.

## Build history and limits

The initial script stopped on an empty Node01 container list. The guard was corrected. Cluster creation then succeeded, but the parser expected `id` while WEKA emitted `Container ID`. The parser was corrected and a cluster-specific continuation completed drives, protection, filesystem, mounts, and tests. Static syntax/guard/parser checks passed. The complete corrected build has not been repeated on a second fresh lab.

Preserve raw command outputs and record future shared-file, persistent-mount, reboot, checkpoint-restore, admin/license/TLS, and memory-sizing results separately. Sequential fio results must not be added as concurrent aggregate throughput.
