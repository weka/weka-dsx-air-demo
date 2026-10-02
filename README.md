# WEKA in NVIDIA DSX Air

An eight-backend WEKA 5.1.34 lab with two clients and one Cumulus switch.

![Lab topology](labs/8node/images/weka_8node_air_topology.jpg)

Use the [lab guide](labs/8node/README.md) for cluster creation, client mounts, verified fio writes/reads, GUI access, and clean checkpoints.

| Resource | Location |
|---|---|
| Air topology | [topology.json](labs/8node/topology.json) |
| Node inventory | [inventory.json](labs/8node/inventory.json) |
| Switch connections | [port-map.csv](labs/8node/port-map.csv) |
| Backend data addresses | [storage.8](labs/8node/storage.8) |
| Script descriptions | [Script guide](docs/script-guide.md) |
| Observed results and limits | [Validation record](docs/validation-record.md) |
| 30-minute demonstration | [Demo agenda](docs/demo-agenda.md) |
| GitHub handoff | [Publishing](docs/publishing.md) |

This repository contains no installer token, license, passwords, or private SSH keys. The lab demonstrates functionality; simulated throughput is not a production benchmark. The data network is L2 VLAN 100; this is not an L3 or RDMA deployment.

The reset script deletes the lab's filesystem data. It targets the documented ten management IPs and does not require a cluster UUID or cluster login.
