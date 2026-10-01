# WEKA Eight-Node Demo for NVIDIA DSX Air

The standard lab uses eight WEKA backends, two clients, and one virtual Cumulus data switch. The deployment was validated on October 1, 2026.

## Standard topology

| Lab | Validated release | Cluster health | Guide | Topology |
| --- | --- | --- | --- | --- |
| Eight backends + two clients | 5.1.34 | 8 backends/drives UP, 5+2 protected, 1 hot spare, I/O STARTED, 2 clients | [Eight-node guide](labs/8node/README.md) | [JSON](labs/8node/topology.json) |

## Eight-node lab in DSX Air

![Eight WEKA backends, two clients, data switch, and OOB management](labs/8node/images/weka_8node_air_topology.jpg)

The eight-node cluster has 198.56 GiB usable drive storage and an 80 GiB filesystem mounted on both clients at `/mnt/weka`. Separate 30-second write tests completed with zero errors: Client01 76.1 MiB/s and Client02 74.1 MiB/s. These virtual-lab results are not aggregate or production benchmarks.

## Start here

1. For the running demo, resume the configured simulation and follow the eight-node guide's validation flow.
2. For a fresh build, import the eight-node JSON with OOB enabled. JSON import creates topology and disks only; it does not restore WEKA software or cluster data.
3. Check available resources. The eight-node JSON allocates 58 vCPU and 212 GiB RAM; Air reported about 218 GiB with overhead. The quota issue was resolved and this lab booted.
4. Use node consoles for initial access, then set up internal management SSH, approved WEKA software, host data addresses, and the switch as described in the guide.
5. Run the build only on unused eight-node VMs. It changes initial containers and provisions the verified data/swap disks. Do not run it on the existing cluster.
6. Inspect health, mounts, alerts, and client tests. Keep the completed simulation separately from the topology export.

## Repository contents

| Path | Purpose |
| --- | --- |
| `labs/8node/` | Air-style guides, topology JSON, inventories, IP lists, port maps, network fragments, diagrams/screenshots |
| `labs/8node/scripts/02_create_8backend_2client_weka_demo.sh` | Fresh eight-node build after WEKA, SSH, and network preparation |
| `labs/8node/scripts/04_continue_8backend_2client_weka_demo.sh` | Original cluster-specific recovery before drive addition; historical, not a general resume command |
| `0_preflight.sh`–`3_fio_smoke_test.sh` | Shared preflight, network preview/apply, validation, and fio helpers |
| `scripts/check_repository.py` | Static package/topology/link checks |
| `docs/validation-record.md` | Captured results and remaining checks |
| `docs/script-guide.md` | Script prerequisites and limitations |
| `docs/publishing.md` | Updating the existing GitHub repository from the Mac |

## Remaining work

The eight-node lab is Unlicensed with five alerts: client low available memory on both clients, default admin password, and system-defined TLS. Clients have 8 GiB RAM; increasing each to 16 GiB is proposed and has not been applied. Client mounts are temporary. Shared-file checksum output, persistent mounts, reboot/checkpoint restore, and external Mac SSH remain unvalidated.

Use the eight-node defaults for all root helpers, for example `bash 0_preflight.sh`, `bash 2_validate_lab.sh`, or `bash 3_fio_smoke_test.sh` (preview). Explicit `--lab 8node` is also accepted.

The corrected complete build script has not been rerun in one pass on another fresh simulation; successful commissioning used the build and continuation after correcting the CSV parser. This record distinguishes functional results from pending checks.

Run package checks from the repository root:

```bash
python3 scripts/check_repository.py
```

These checks validate files and links, not live VM health. WEKA installer credentials, binaries, licenses, private keys, and VM backups are not included. No license or ownership terms have been assigned automatically.

## References and contact

- [NVIDIA DSX Air](https://dsx-air.nvidia.com/)
- [NVIDIA DSX Air Quick Start](https://docs.nvidia.com/networking-ethernet-software/nvidia-air/Quick-Start/)
- Structural reference: `githedgehog/nvidia-air-demo`; no Hedgehog source code was copied.
- Lab owner: Chandra Sekhar Gonuguntla (Sekhar). Use the approved WEKA support contact and Air organization administrator.
