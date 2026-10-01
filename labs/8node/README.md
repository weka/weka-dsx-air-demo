<!-- AIR:tour -->

# WEKA 8-Backend, 2-Client Lab in NVIDIA DSX Air

WEKA provides a shared filesystem backed by distributed storage. This lab uses eight Ubuntu backend VMs, two Ubuntu clients, and one virtual Cumulus switch. You will inspect cluster health and protection, verify the network and mounts, and demonstrate shared-file access and basic I/O.

**Validated October 1, 2026:** WEKA 5.1.34 reports eight backend containers and eight drives UP, 5+2 fully protected, one hot spare, I/O STARTED, and two connected clients. Both clients completed write smoke tests without errors.

The main flow demonstrates the running lab. Start from a saved configured simulation. Importing [topology.json](topology.json) creates the VMs and disks only; it does not install WEKA or restore cluster state. Fresh-build instructions are provided separately.

**Important:** This functional demo uses UDP and emulated NVMe. It does not measure physical switch, NVMe, or RDMA performance. The validated clients have 8 GiB RAM and low available-memory alerts. Current mounts do not persist after reboot.

## Table of Contents

- [Lab Story and Scenario](#lab-story-and-scenario)
- [Features and Services](#features-and-services)
- [What You Will Do in This Lab](#what-you-will-do-in-this-lab)
- [Demo Topology Overview](#demo-topology-overview)
- [Demo Topology Information](#demo-topology-information)
- [Demo Environment Access](#demo-environment-access)
- [Lab Flow](#lab-flow)
- [Fresh Build](#fresh-build)
- [Validation Summary](#validation-summary)
- [Troubleshooting, Upgrade, or Reset](#troubleshooting-upgrade-or-reset)
- [References](#references)
- [Contact Info](#contact-info)

## Lab Story and Scenario

You are a platform engineer checking shared storage before application teams use it. Inspect the network path, backend health, drives, protection, and client mounts. Then write a small file through one client and read it through the other. A short write workload completes the functional demonstration.

## Features and Services

- Eight WEKA 5.1.34 backends, each with a 48 GB emulated NVMe data disk and a separate 8 GB swap disk.
- Two native WEKA filesystem clients using kernel UDP networking.
- Cumulus Linux 5.16.1 on `SN5600-1`, access VLAN 100, and MTU 9000 on data ports.
- Dedicated deployment, eight failure domains, 5+2 protection, and one hot spare.
- Filesystem `default`, group `group1`, 80 GiB, mounted on both clients at `/mnt/weka`.
- Separate Air OOB management with a management server and switch.

## What You Will Do in This Lab

- Identify node roles, addresses, and data-port connections.
- Check jumbo-frame reachability, backend health, protection, and capacity.
- Verify mounts, demonstrate shared-file access, and run separate write smoke tests.
- Record alerts and preserve the configured simulation.

<!-- AIR:page -->

## Demo Topology Overview

Each backend and client uses `eth0` for management and `eth1` for WEKA data traffic. All ten data interfaces connect to `SN5600-1`. Untagged host traffic is carried in switch access VLAN 100; hosts do not use VLAN subinterfaces. Air provides the OOB management server and switch in addition to the explicit topology nodes.

![Eight WEKA backends, two clients, SN5600-1, and Air OOB management](images/weka_8node_air_topology.jpg)

### Device Naming

`WekaNode01`–`WekaNode08` are storage backends. `Client01` and `Client02` consume the filesystem. `SN5600-1` is the data switch. `oob-mgmt-server` and `oob-mgmt-switch-leaf-1` provide management access.

### Devices

| Role | Names | Resources in the validated topology |
| --- | --- | --- |
| Backend | WekaNode01–08 | 6 vCPU, 24 GiB RAM, 32 GB boot disk, 48 GB data NVMe, 8 GB swap NVMe |
| Client | Client01, Client02 | 4 vCPU, 8 GiB RAM, 20 GB boot disk |
| Data switch | SN5600-1 | 2 vCPU, 4 GiB RAM, Cumulus VX 5.16.1 |
| Management | oob-mgmt-server, oob-mgmt-switch-leaf-1 | Air-provided infrastructure |

Ubuntu image: `generic/ubuntu2204`; backend/client CPU mode: host-passthrough. The explicit topology allocates 58 vCPU and 212 GiB RAM; Air reported approximately 218 GiB including overhead. The organization quota was increased and deployment completed. Increasing both clients to 16 GiB is recommended for this demo's headroom, but has not been applied; it would add 16 GiB to the total.

<!-- AIR:page -->

## Demo Topology Information

### IPAM

| Host | Management eth0 /24 | Data eth1 /24 | Data VLAN | Data MTU |
| --- | --- | --- | --- | --- |
| WekaNode01 | 192.168.200.11 | 10.200.100.11 | 100, untagged | 9000 |
| WekaNode02 | 192.168.200.12 | 10.200.100.12 | 100, untagged | 9000 |
| WekaNode03 | 192.168.200.13 | 10.200.100.13 | 100, untagged | 9000 |
| WekaNode04 | 192.168.200.14 | 10.200.100.14 | 100, untagged | 9000 |
| WekaNode05 | 192.168.200.15 | 10.200.100.15 | 100, untagged | 9000 |
| WekaNode06 | 192.168.200.16 | 10.200.100.16 | 100, untagged | 9000 |
| WekaNode07 | 192.168.200.17 | 10.200.100.17 | 100, untagged | 9000 |
| WekaNode08 | 192.168.200.18 | 10.200.100.18 | 100, untagged | 9000 |
| Client01 | 192.168.200.21 | 10.200.100.21 | 100, untagged | 9000 |
| Client02 | 192.168.200.22 | 10.200.100.22 | 100, untagged | 9000 |
| SN5600-1 | 192.168.200.3 | No data IP needed | br_default, VLAN 100 | Data ports 9000 |

The switch management interface uses its management VRF. Hosts use ordinary Linux routing without separate VRFs. Node01's observed management gateway is `192.168.200.254`. No data gateway is needed for traffic within this subnet.

### Physical Connectivity

These are virtual links; [port-map.csv](port-map.csv) contains the same mapping.

| Host | Host port | SN5600-1 port |
| --- | --- | --- |
| WekaNode01 | eth1 | swp1s0 |
| WekaNode02 | eth1 | swp1s1 |
| WekaNode03 | eth1 | swp2 |
| WekaNode04 | eth1 | swp3 |
| WekaNode05 | eth1 | swp4 |
| Client01 | eth1 | swp5 |
| Client02 | eth1 | swp6 |
| WekaNode06 | eth1 | swp7 |
| WekaNode07 | eth1 | swp8 |
| WekaNode08 | eth1 | swp9 |

### Backend Disks

| Device | Observed size | Serial pattern | Purpose |
| --- | --- | --- | --- |
| /dev/vda | 29.8 GiB | Not used for WEKA identification | Ubuntu boot/root |
| /dev/vdb | 350 KiB | Air ISO | Air initialization data |
| /dev/nvme0n1 | 44.70 GiB | weka01–weka08 | WEKA data |
| /dev/nvme1n1 | 7.5 GiB | swap01–swap08 | Linux swap |

Topology capacities are expressed in GB; Linux reports GiB. Check disk serials, signatures, and mountpoints before initialization. Do not choose disks only by name or size.

<!-- AIR:page -->

## Demo Environment Access

### Load Time and Readiness

Boot time has not been measured. Wait for ACTIVE and node login prompts. On a configured simulation, check `weka status` before testing. Client remounts can take tens of seconds while their containers start.

### Console Access and Device Credentials

Open WekaNode01's console in Air. Login user is `ubuntu`. The Ubuntu image default password is `nvidia` if unchanged; the actual passwords used during validation were not recorded. Consult the node credential panel or lab owner for current passwords.

| Device | Username | Authentication | Management IP |
| --- | --- | --- | --- |
| WekaNode01–08 | ubuntu | Image default nvidia if unchanged; current password from node panel/owner | 192.168.200.11–18 |
| Client01, Client02 | ubuntu | Passwordless SSH from Node01 verified; console password as above | 192.168.200.21–22 |
| SN5600-1 | cumulus | Current password from node panel/owner; not recorded | 192.168.200.3 |
| oob-mgmt-server | ubuntu | Air credential panel | Air-assigned |

### SSH Access

Node01's SSH key and passwordless `sudo -n` were verified on all ten Ubuntu hosts. External Mac SSH was not successfully validated. For external access, use current Air Services information and an authorized key; worker names and ports may change.

Full terminal prompts show where to run commands. Copy only the command after `$`.

```bash
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.21
ubuntu@Client01:~$ hostname
Client01
ubuntu@Client01:~$ exit
```

No installer token, license, or private key is included in the repository. The default WEKA admin-password warning remains active; this guide does not assume the current admin credential.

<!-- AIR:page -->

## Lab Flow

### Step 1. Verify cluster readiness

**Goal:** Confirm healthy storage before client tests. **Access/credentials:** WekaNode01 console as `ubuntu`, password `nvidia` if unchanged or the current node-panel/owner password. **Expected wait:** A few seconds per query after startup completes.

```bash
ubuntu@WekaNode01:~$ weka version
* 5.1.34
ubuntu@WekaNode01:~$ weka status
ubuntu@WekaNode01:~$ weka cluster container
ubuntu@WekaNode01:~$ weka cluster drive
ubuntu@WekaNode01:~$ weka fs
```

Expected: cluster `WekaDSXAirDemo8Node`, status OK, eight backends and eight drives UP, 5+2 fully protected, hot spare 1, I/O STARTED, and two clients. All data disks should be ACTIVE with attachment OK. Client IDs were 8 and 9 in this build; IDs can differ after another deployment.

### Step 2. Verify data network and switch

**Goal:** Confirm a working 9000-byte data path. **Access/credentials:** Node01 as `ubuntu`; switch SSH as `cumulus` with its current node-panel/owner password. **Expected wait:** Approximately 20 seconds for the pings, plus login time.

```bash
ubuntu@WekaNode01:~$ ip -br a
ubuntu@WekaNode01:~$ for n in 12 13 14 15 16 17 18 21 22; do ping -I eth1 -c 2 -W 3 -M do -s 8972 "10.200.100.$n"; done
ubuntu@WekaNode01:~$ ssh cumulus@192.168.200.3
cumulus@SN5600-1:~$ nv show bridge domain br_default
cumulus@SN5600-1:~$ ip -br link
cumulus@SN5600-1:~$ exit
```

Expected: zero packet loss to the seven other backends and both clients. The ten data ports should forward in `br_default`, access VLAN 100, MTU 9000. For failed pings, check host/switch MTU and bridge membership before changing WEKA.

### Step 3. Verify client mounts

**Goal:** Confirm both clients mount the native filesystem. **Access/credentials:** Node01 `ubuntu`, installed SSH key to both client `ubuntu` accounts; no password required. **Expected wait:** A few seconds.

```bash
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[21-22]' 'hostname; findmnt -T /mnt/weka; df -h /mnt/weka; sudo -n weka local ps'
```

Expected: type `wekafs`, source `10.200.100.11/default`, mount `/mnt/weka`, about 80 GiB capacity, and client container Running/Ready. An existing directory alone is not proof of a mount.

### Step 4. Demonstrate shared-file access

**Goal:** Write through Client01 and read through Client02. **Access/credentials:** Node01 `ubuntu`, key-based SSH to client `ubuntu` accounts. **Expected wait:** A few seconds. This guided test has not yet been captured in the validation record.

```bash
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.21 'test "$(findmnt -n -o FSTYPE -T /mnt/weka)" = wekafs && printf "WEKA shared filesystem check\n" > /mnt/weka/air-shared-file-check.txt && sha256sum /mnt/weka/air-shared-file-check.txt'
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.22 'test "$(findmnt -n -o FSTYPE -T /mnt/weka)" = wekafs && cat /mnt/weka/air-shared-file-check.txt && sha256sum /mnt/weka/air-shared-file-check.txt'
```

Expected: Client02 prints `WEKA shared filesystem check`; both checksums match. The demo build made the filesystem root writable by `ubuntu`. Use a dedicated application directory for later workloads.

### Step 5. Run a write smoke test

**Goal:** Demonstrate error-free writes. **Access/credentials:** Node01 key-based SSH to Client01 as `ubuntu`. **Expected wait:** 30 seconds plus file initialization. Approximately 2 GiB of test files remain in a unique directory.

```bash
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.21
ubuntu@Client01:~$ test "$(findmnt -n -o FSTYPE -T /mnt/weka)" = wekafs
ubuntu@Client01:~$ FIO_DIR="/mnt/weka/fio-demo-$(hostname)-$(date +%Y%m%d-%H%M%S)"
ubuntu@Client01:~$ mkdir -p "$FIO_DIR"
ubuntu@Client01:~$ fio --name=weka-write-Client01 --directory="$FIO_DIR" --rw=write --bs=1M --size=1G --numjobs=2 --iodepth=8 --ioengine=libaio --direct=1 --runtime=30 --time_based --group_reporting
ubuntu@Client01:~$ exit
```

Repeat separately on Client02 at `192.168.200.22`, using its `ubuntu` account, Node01's key, prompt `ubuntu@Client02`, and name `weka-write-Client02`. Success means `err=0`. Recorded results: Client01 76.1 MiB/s; Client02 74.1 MiB/s. These were separate runs, not combined throughput. Air contention can change results.

### Step 6. Review alerts and preserve results

**Goal:** Capture success and remaining issues. **Access/credentials:** Node01 as `ubuntu`; client SSH uses its key. **Expected wait:** A few seconds.

```bash
ubuntu@WekaNode01:~$ weka alerts
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[21-22]' 'hostname; free -h; ps -eo pid,comm,rss --sort=-rss | head -n 10'
```

Recorded: five alerts, comprising two client available-memory alerts and warnings for default admin password, missing license, and system-defined TLS. Both clients later showed approximately 2.1 GiB available RAM, below the 3000 MB threshold.

Preserve the configured simulation using the Air organization's available save/checkpoint workflow. Topology export is not a VM/data backup. Restore and reboot behavior have not been validated.

<!-- AIR:page -->

## Fresh Build

Use this section only for a newly imported, unused eight-backend topology. Do not run fresh-build scripts against an initialized eight-node cluster.

The [build script](scripts/02_create_8backend_2client_weka_demo.sh) initializes swap, removes initial STEM containers, creates UDP backends, forms the cluster, discovers container IDs, adds verified disks, starts I/O with 5+2 protection and one hot spare, creates the filesystem, and mounts/tests both clients. It does not install WEKA or configure the switch/host networking. It contains fixes for the empty-host guard and WEKA CSV headers encountered during commissioning. The corrected complete build has not been rerun in one pass on a second fresh simulation.

### Prepare management SSH and WEKA

**Access/credentials:** Node01 as `ubuntu`, current console password; image default `nvidia` if unchanged. Enter each target's current Ubuntu password at `ssh-copy-id`. **Expected wait:** Up to ten password entries; software download time varies.

```bash
ubuntu@WekaNode01:~$ if [ ! -f ~/.ssh/id_ed25519 ]; then ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''; fi
ubuntu@WekaNode01:~$ for n in 11 12 13 14 15 16 17 18 21 22; do ssh-copy-id -i ~/.ssh/id_ed25519.pub -o StrictHostKeyChecking=accept-new ubuntu@192.168.200.$n; done
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[11-18],192.168.200.[21-22]' 'hostname; sudo -n true; weka version; sudo -n weka local ps'
```

Install approved WEKA 5.1.34 software on all ten hosts before the build. Obtain the authorized installer URL through the WEKA account contact; its credential is not embedded in the repository. Verify version 5.1.34 and initial default containers in STEM mode. Software installation and initial startup were completed separately in the recorded lab. The build requires Python 3 and OpenSSH on Node01; network/validation examples use pdsh.

### Configure fresh switch and hosts

**Access/credentials:** Switch console as `cumulus` using its current node-panel/owner password; Node01 `ubuntu` uses internal SSH keys. **Expected wait:** Allow NVUE/Netplan to finish and SSH to settle; keep consoles available.

These switch settings were validated in the eight-node lab:

```bash
cumulus@SN5600-1:~$ sudo ztp -d
cumulus@SN5600-1:~$ nv set bridge domain br_default vlan 100
cumulus@SN5600-1:~$ for p in swp1s0 swp1s1 swp2 swp3 swp4 swp5 swp6 swp7 swp8 swp9; do nv set interface "$p" bridge domain br_default; nv set interface "$p" bridge domain br_default access 100; nv set interface "$p" link mtu 9000; done
cumulus@SN5600-1:~$ nv config apply
cumulus@SN5600-1:~$ nv show bridge domain br_default
```

Host files under `config/netplan` specify only `eth1`: the expected /24 address, MTU 9000, and DHCP disabled. Back up current Netplan files and inspect the merged configuration. From the full repository root on Node01, preview then apply the host helper on the fresh lab:

```bash
ubuntu@WekaNode01:~/weka-dsx-air-demo$ bash 1_setup_data_network.sh --lab 8node
ubuntu@WekaNode01:~/weka-dsx-air-demo$ bash 1_setup_data_network.sh --lab 8node --apply
ubuntu@WekaNode01:~/weka-dsx-air-demo$ bash 0_preflight.sh --lab 8node
```

These root helpers require the full repository. Validate all management/data addresses, passwordless SSH/sudo, disk serials, and Step 2 jumbo pings before building.

### Build the fresh cluster

**Access/credentials:** Run as `ubuntu` on WekaNode01 with the installed SSH key and passwordless sudo. **Expected wait:** Several minutes for container/cluster startup and two 30-second tests, plus any client fio package installation. The health wait has a ten-minute timeout.

```bash
ubuntu@WekaNode01:~/weka-dsx-air-demo$ bash labs/8node/scripts/02_create_8backend_2client_weka_demo.sh
```

Defaults: cluster `WekaDSXAirDemo8Node`; filesystem `default`; group `group1`; size 80 GiB; mount `/mnt/weka`. Each backend is configured with 3 cores and 4 GiB WEKA memory. The recorded UDP container table displayed `CORES 0`; this column is recorded as observed rather than used to infer effective process allocation. Cluster status showed 24 I/O nodes UP.

The [continuation script](scripts/04_continue_8backend_2client_weka_demo.sh) is specific to the recorded original cluster UUID after its parser failure and before drive addition. It is not a general recovery tool and must not be run against the now-initialized cluster.

## Validation Summary

Terminal evidence was captured October 1, 2026, around 08:35 Pacific. The author inspected supplied output rather than directly accessing the VMs.

| Check | Observed result |
| --- | --- |
| WEKA | 5.1.34 on eight backends and two clients |
| Cluster | WekaDSXAirDemo8Node; UUID ba6d7699-3df0-4ada-a00e-29855bb03df1 |
| Health | OK; 8 backends UP; 8 drives UP and ACTIVE, attachment OK |
| Protection | 5+2 fully protected |
| Hot spare | 1 failure domain, 28.12 GiB |
| Drive storage | 198.56 GiB total usable, 118.56 GiB unprovisioned |
| Filesystem | default / group1, 80 GiB; both clients mounted at /mnt/weka |
| I/O | STARTED; 24 I/O nodes UP; 6 buckets UP |
| Clients | 2 connected; Running/Ready |
| Jumbo pings | Node01 to seven backends and both clients: zero packet loss |
| Client01 write | 76.1 MiB/s, 30.222 seconds, err=0 |
| Client02 write | 74.1 MiB/s, 30.115 seconds, err=0 |
| License / alerts | Unlicensed; five alerts |
| Shared-file checksums | Guided test supplied; result not captured |
| Reboot / checkpoint restore | Not validated; mounts are temporary |

## Troubleshooting, Upgrade, or Reset

### Client memory alerts

Both clients have 8 GiB RAM and approximately 2.1 GiB available, below the recorded 3000 MB threshold. Increasing each to 16 GiB is a proposed sizing improvement; it has not been applied. Shared pages can appear in multiple process RSS values, so do not sum RSS to calculate unique usage. Plan remounts before any resource change that restarts a client.

### Remount after a client restart

**Access/credentials:** Node01 key-based SSH to Client01 `ubuntu`; passwordless sudo. **Expected wait:** Tens of seconds for the mount/client startup. Run only when the filesystem is not mounted.

```bash
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.21
ubuntu@Client01:~$ sudo -n mkdir -p /mnt/weka
ubuntu@Client01:~$ mountpoint -q /mnt/weka || sudo -n mount -t wekafs -o net=udp,num_cores=0,mgmt_ip=10.200.100.21 10.200.100.11/default /mnt/weka
ubuntu@Client01:~$ findmnt -T /mnt/weka
ubuntu@Client01:~$ df -h /mnt/weka
ubuntu@Client01:~$ exit
```

For Client02 use SSH address `192.168.200.22`, its `ubuntu` account, prompt `ubuntu@Client02`, and mount option `mgmt_ip=10.200.100.22`. Expected type is `wekafs` and capacity approximately 80 GiB. Persistent mount setup remains a follow-up task.

### Other alerts and recovery

Address the default admin password, license, and TLS warnings through approved WEKA administration. A successful I/O test does not clear them. Capture `weka status`, `weka cluster container`, `weka cluster drive`, `weka alerts`, and build logs before recovery. Do not rerun backend cleanup after cluster creation.

The corrected build accepts an empty initial host, skips absent-container removal, and handles WEKA's `Container ID` CSV header. Build logs are under `~/weka-8node-build-YYYYMMDD-HHMMSS/`. No destructive reset is part of this demonstration flow.

### Upgrade

This eight-node lab uses validated WEKA 5.1.34. Plan upgrades separately with compatibility/license checks. Upgrade, failure/rebuild, reboot, and checkpoint recovery tests were not performed in this record.

## References

- [NVIDIA DSX Air](https://dsx-air.nvidia.com/)
- [NVIDIA DSX Air Quick Start](https://docs.nvidia.com/networking-ethernet-software/nvidia-air/Quick-Start/)
- [Cumulus Linux 5.16 documentation](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-516/)
- Partner documentation titles: WEKA 5.1 CLI reference, manual cluster configuration, native filesystem mounts, and alert administration. Obtain these through the approved WEKA documentation channel.

## Contact Info

| Contact type | Contact path |
| --- | --- |
| Lab owner | Chandra Sekhar Gonuguntla (Sekhar) |
| WEKA installation, license, or software | Approved WEKA support/account contact |
| Air quota and simulation access | Air organization administrator / NVIDIA DSX Air team |

This guide follows the supplied Air template. GitHub packaging is separate from any future publication to an NVIDIA-hosted lab catalog.
