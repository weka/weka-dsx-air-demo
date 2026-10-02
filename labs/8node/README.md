<!-- AIR:tour -->

# WEKA Eight-Backend Storage Lab in NVIDIA DSX Air

This lab demonstrates how to create and use a WEKA distributed filesystem in NVIDIA DSX Air. WEKA provides shared storage that multiple application clients can access through a common filesystem. In this lab, eight simulated backend servers provide storage to two Ubuntu clients over an Ethernet data network.

You will create the cluster and filesystem, mount both clients, write and read shared data, run fio checksum verification, and inspect the cluster through the WEKA GUI. You will also learn how to reset the storage and preserve a clean starting point using an Air checkpoint.

**Starting state:** The clean checkpoint contains installed WEKA 5.1.34 software, prepared networking, SSH access, and lab scripts. The WEKA cluster and filesystem are created during the lab. Importing the topology JSON alone does not install software or prepare this configuration.

**Important:** Use the clean checkpoint selected by the lab publisher. The reset step permanently deletes the lab cluster's filesystem data. Simulated throughput is not a production benchmark. This lab uses UDP over L2 VLAN 100; it does not demonstrate RDMA or an L3 fabric. Software licensing and any credentials changed from those documented below must be supplied by the lab owner.

## Table of Contents

- [Lab Story and Scenario](#lab-story-and-scenario)
- [Features and Services](#features-and-services)
- [What You Will Do in This Lab](#what-you-will-do-in-this-lab)
- [Demo Topology Overview](#demo-topology-overview)
- [Demo Topology Information](#demo-topology-information)
- [Demo Environment Access](#demo-environment-access)
- [Lab Flow](#lab-flow)
- [Validation Summary](#validation-summary)
- [Troubleshooting, Upgrade, or Reset](#troubleshooting-upgrade-or-reset)
- [References](#references)
- [Contact Info](#contact-info)

## Lab Story and Scenario

You are a platform engineer preparing a shared storage environment for application testing. Before using physical infrastructure, you want to practice cluster creation, verify client access, and understand the operational checks needed to establish a healthy filesystem.

Air provides the simulated servers and network. WEKA provides the shared filesystem. Automation separates cluster creation, mounting, data verification, and reset into distinct steps so you can inspect each stage and troubleshoot a failed check.

By the end, both clients should access the same filesystem, read one another's data, and complete checksum verification. A clean checkpoint allows the environment to be launched again without relying on restoration of an existing WEKA cluster's data.

## Features and Services

- Eight WEKA backend containers with one data disk per backend.
- Five data drives and two parity drives per protection stripe, plus one hot-spare failure domain.
- An 80 GiB filesystem named `default` in filesystem group `group1`.
- Native WEKA filesystem mounts on `Client01` and `Client02` using UDP networking.
- Shared-file checks and fio write/read verification using CRC32C.
- WEKA HTTPS GUI on port `14000`, accessed through an Air service and OOB relay.
- Separate management and data interfaces; data MTU `9000`.
- A reset script that identifies disks by serial and verifies full-device zeroing.

## What You Will Do in This Lab

1. Verify the prepared environment and data network.
2. Create the eight-backend cluster and filesystem.
3. Mount the filesystem on both clients.
4. Write from one client and read from the other.
5. Run fio writes and cross-client verified reads.
6. Access the GUI and inspect health, drives, filesystem, and clients.
7. Unmount, reset, and save a clean checkpoint for another launch.

<!-- AIR:page -->

## Demo Topology Overview

`WekaNode01` through `WekaNode08` are storage backends. `Client01` and `Client02` access the shared filesystem. Their `eth1` data interfaces connect to `SN5600-1`, a Cumulus Linux switch configured for access VLAN `100` and jumbo frames.

Air adds an OOB management network and `oob-mgmt-server`. Management access uses `eth0`, independently of the storage data network. The OOB server provides access into the lab and can relay the WEKA HTTPS connection for the Air service.

![WEKA eight-backend DSX Air topology](images/weka_8node_air_topology.jpg)

### Device Naming

- `WekaNode01`–`WekaNode08`: eight storage backend servers.
- `Client01`–`Client02`: two filesystem clients.
- `SN5600-1`: storage data switch.
- `oob-mgmt-server`: Air management jump server.

### Devices

| Role | Device names | Resources per device |
|---|---|---|
| Backend | WekaNode01–WekaNode08 | 6 vCPU, 24 GiB RAM, 48 GB data NVMe, 8 GB swap NVMe |
| Client | Client01, Client02 | 4 vCPU, 8 GiB RAM |
| Data switch | SN5600-1 | Cumulus Linux; ten host data connections |
| Management | oob-mgmt-server and Air OOB network | Added by Air; inspect the node panel for assigned resources |

The explicit backend/client allocation totals 56 vCPUs and 208 GiB RAM, before the switch and Air management overhead. The previously observed whole simulation required approximately 218 GB of memory allowance. Use the actual Air resource estimate when launching; quota use and image availability can differ.

<!-- AIR:page -->

## Demo Topology Information

### IPAM

Ubuntu hosts use the default routing table for both interfaces. The Cumulus switch's `eth0` is in its management VRF. VLAN `100` is the switch access VLAN for untagged host `eth1` traffic; the host configuration does not require an `eth1.100` subinterface.

| Hostname | Management eth0 | Data eth1 | Data VLAN | Data MTU |
|---|---|---|---|---|
| WekaNode01 | 192.168.200.11/24 | 10.200.100.11/24 | 100 | 9000 |
| WekaNode02 | 192.168.200.12/24 | 10.200.100.12/24 | 100 | 9000 |
| WekaNode03 | 192.168.200.13/24 | 10.200.100.13/24 | 100 | 9000 |
| WekaNode04 | 192.168.200.14/24 | 10.200.100.14/24 | 100 | 9000 |
| WekaNode05 | 192.168.200.15/24 | 10.200.100.15/24 | 100 | 9000 |
| WekaNode06 | 192.168.200.16/24 | 10.200.100.16/24 | 100 | 9000 |
| WekaNode07 | 192.168.200.17/24 | 10.200.100.17/24 | 100 | 9000 |
| WekaNode08 | 192.168.200.18/24 | 10.200.100.18/24 | 100 | 9000 |
| Client01 | 192.168.200.21/24 | 10.200.100.21/24 | 100 | 9000 |
| Client02 | 192.168.200.22/24 | 10.200.100.22/24 | 100 | 9000 |
| SN5600-1 | 192.168.200.3/24 | L2 switching; no host data IP | 100 | 9000 on host data ports |
| oob-mgmt-server | Assigned by Air; inspect its node panel | Not attached to storage VLAN | — | — |

### Physical Connectivity

These are simulated links, not physical cables.

| Hostname | Local port | Remote port | Remote device |
|---|---|---|---|
| WekaNode01 | eth1 | swp1s0 | SN5600-1 |
| WekaNode02 | eth1 | swp1s1 | SN5600-1 |
| WekaNode03 | eth1 | swp2 | SN5600-1 |
| WekaNode04 | eth1 | swp3 | SN5600-1 |
| WekaNode05 | eth1 | swp4 | SN5600-1 |
| WekaNode06 | eth1 | swp7 | SN5600-1 |
| WekaNode07 | eth1 | swp8 | SN5600-1 |
| WekaNode08 | eth1 | swp9 | SN5600-1 |
| Client01 | eth1 | swp5 | SN5600-1 |
| Client02 | eth1 | swp6 | SN5600-1 |

<!-- AIR:page -->

## Demo Environment Access

### Load Time and Readiness

Allow several minutes for Air resource allocation and node booting. A fixed boot time has not been measured for this guide. Begin when Air shows the simulation as **Active**, consoles accept login, and the management addresses respond.

The checkpoint must contain these scripts in `/home/ubuntu` on `WekaNode01`: `00_teardown.sh`, `01_create_cluster.sh`, `02_mount_clients.sh`, `03_fio_write_read.sh`, and `04_unmount_clients.sh`. The OOB server needs `05_oob_gui_service.sh`. Keep `05b_node01_gui_relay.sh` on Node01 for the optional GUI fallback.

### Console Access

Double-click `WekaNode01` in the topology to open its console. Log in as `ubuntu`. Use `nvidia` only if the lab's Ubuntu default password is unchanged; otherwise use the current credential supplied by the owner. The node's welcome banner describes the workflow and GUI service.

### Device Credentials

| Device | Username | Authentication | Management address |
|---|---|---|---|
| WekaNode01–08 | ubuntu | Console default `nvidia` if unchanged; current owner credential otherwise | 192.168.200.11–18 |
| Client01–02 | ubuntu | Console default `nvidia` if unchanged; current owner credential otherwise | 192.168.200.21–22 |
| oob-mgmt-server | ubuntu | Console password `WekaDsx@123`; external SSH uses an authorized SSH key | Assigned by Air |
| SN5600-1 | cumulus | Current switch password from the lab owner | 192.168.200.3 |
| WEKA GUI/CLI | admin | `Weka.io123` after cluster creation; separate from Ubuntu login | Air service `weka-gui` |

Do not assume an image's original switch or WEKA password remains valid. Scripts use `ubuntu` SSH keys and passwordless sudo from Node01. The creation script changes the fresh cluster's default `admin` password to the lab password `Weka.io123`, then authenticates both root and ubuntu CLI profiles. It contains no installer token. The OOB console password is `WekaDsx@123`; this is separate from WEKA authentication.

### SSH Access

In Air, open **Services** and inspect the OOB SSH service. Register your public SSH key in your Air account settings as required. Use the exact external hostname and port displayed by that service; these may change for a new launch.

After connecting to OOB, use the lab's management addresses. The Ubuntu account is `ubuntu`; its default console password is `nvidia` if unchanged, but SSH may require the prepared key or current owner credential.

```bash
ubuntu@oob-mgmt-server:~$ ssh ubuntu@192.168.200.11
ubuntu@WekaNode01:~$ hostname
WekaNode01
```

To inspect the switch, use account `cumulus` and its current owner-supplied password:

```bash
ubuntu@oob-mgmt-server:~$ ssh cumulus@192.168.200.3
cumulus@SN5600-1:~$ nv show bridge domain br_default
cumulus@SN5600-1:~$ exit
```

### GUI Access

Use **Services → weka-gui** and open the HTTPS link assigned to this simulation. Its external port may differ from `14000`. After cluster creation, sign in as `admin` with password `Weka.io123` unless `WEKA_ADMIN_PASSWORD` was overridden when running the creation script.

The private addresses `192.168.200.11` and `10.200.100.11` are inside the lab. A Mac outside the simulation cannot reach them directly without a routed connection. The GUI relay and Air service are configured in Step 6.

<!-- AIR:page -->

## Lab Flow

Command examples include the prompt to identify the node and login context. Copy the command after `$`, not the prompt itself. Expected results below are success criteria, not claims that a new launch has already passed.

### Step 1. Verify the clean starting state

**Goal:** Confirm the prepared checkpoint is ready for cluster creation.

**Access needed:** `WekaNode01` console or SSH from OOB.

**Credentials for this step:** Ubuntu account `ubuntu`; console password `nvidia` if unchanged, otherwise the owner's current password. Remote automation requires prepared SSH keys and passwordless sudo.

**Expected wait time:** Usually seconds per inspection; the script checks all ten hosts. Boot readiness has no guaranteed duration.

```bash
ubuntu@WekaNode01:~$ hostname
ubuntu@WekaNode01:~$ weka version
ubuntu@WekaNode01:~$ sudo -n weka local ps
ubuntu@WekaNode01:~$ ip -br a
ubuntu@WekaNode01:~$ cat /sys/class/net/eth1/mtu
ubuntu@WekaNode01:~$ lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL
ubuntu@WekaNode01:~$ ls -l ~/00_teardown.sh ~/01_create_cluster.sh ~/02_mount_clients.sh ~/03_fio_write_read.sh ~/04_unmount_clients.sh
```

Expected results: hostname `WekaNode01`, active WEKA version `5.1.34`, empty container list, `eth1` at `10.200.100.11/24`, MTU `9000`, and the scripts present. Active swap is expected and is allowed by the corrected creation script. The data disk should be blank, approximately 44.7 GiB, serial `weka01`; the 7.5 GiB swap disk is serial `swap01`.

Validation of access to all hosts:

```bash
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[11-18],192.168.200.[21-22]' 'hostname; sudo -n true; cat /sys/class/net/eth1/mtu'
```

All ten hostnames should appear without SSH or sudo errors, and each MTU should be `9000`. Do not start a fresh build if a cluster already exists or disk numbering/signatures differ from the script's assumptions.

### Step 2. Verify the data network

**Goal:** Confirm all storage and client interfaces have a jumbo-frame path through the switch.

**Access needed:** `WekaNode01`; optional switch console.

**Credentials for this step:** Node01 account `ubuntu`, password `nvidia` if unchanged or current owner credential; optional switch account `cumulus` with its current owner-supplied password.

**Expected wait time:** Roughly 20–40 seconds for the sequential ping checks, longer if addresses time out.

```bash
ubuntu@WekaNode01:~$ for n in 12 13 14 15 16 17 18 21 22; do ping -I eth1 -c 2 -W 3 -M do -s 8972 "10.200.100.$n" || break; done
```

Expected: replies from all nine targets, with zero packet loss. The `8972`-byte payload plus IPv4/ICMP headers tests the 9000-byte path.

Alternate validation from the switch:

```bash
ubuntu@WekaNode01:~$ ssh cumulus@192.168.200.3
cumulus@SN5600-1:~$ nv show bridge domain br_default
cumulus@SN5600-1:~$ ip -br link
cumulus@SN5600-1:~$ exit
```

Expected: the ten listed data ports in `br_default`, access VLAN `100`, with usable links. Resolve network errors before creating the cluster.

### Step 3. Create the cluster and filesystem

**Goal:** Provision eight backends and an 80 GiB shared filesystem.

**Access needed:** `WekaNode01`, running automation against all ten hosts.

**Credentials for this step:** Account `ubuntu`, password `nvidia` if unchanged or owner credential for initial login; prepared SSH keys and passwordless sudo for automation. The creation script sets WEKA user `admin` to password `Weka.io123` and logs in both root and ubuntu CLI profiles.

**Expected wait time:** Several minutes. The script bounds initial container readiness waits and allows up to ten minutes for the final healthy I/O check. Total time depends on Air resources; measure the actual run.

```bash
ubuntu@WekaNode01:~$ time bash ~/01_create_cluster.sh
```

The script checks all hosts, prepares swap, creates three-core/4 GiB UDP backend containers in separate failure domains, forms the cluster, discovers actual container IDs, and adds the verified data disks. It changes the fresh cluster's default admin password to `Weka.io123`, authenticates the root and ubuntu CLI profiles, and displays the GUI credentials at completion outside the build log. Set `WEKA_ADMIN_PASSWORD` before running if using a different lab password. It sets 5+2 protection and one hot-spare failure domain, starts I/O, and creates `group1/default` with size `80GiB`.

Validation:

```bash
ubuntu@WekaNode01:~$ weka status
ubuntu@WekaNode01:~$ weka cluster container
ubuntu@WekaNode01:~$ weka cluster drive
ubuntu@WekaNode01:~$ weka fs
```

Expected: cluster `WekaDSXAirDemo8Node`, eight backend containers and eight drives UP, protection fully protected, I/O STARTED, and filesystem `default` in `group1`. Before mounting, zero connected clients is normal. Each new cluster receives a new UUID.

If authentication is required, log in as WEKA user `admin` with password `Weka.io123` after the creation script has changed it, or the overridden password, then repeat the read-only checks:

```bash
ubuntu@WekaNode01:~$ weka user login
```

If the build stops, preserve its `weka-8node-build-*` log and inspect the failed phase. Do not blindly rerun a partially completed creation script.

### Step 4. Mount clients and demonstrate shared data

**Goal:** Mount the same filesystem on both clients and prove that data written by one is visible to the other.

**Access needed:** `WekaNode01`; the script connects to `Client01` and `Client02`.

**Credentials for this step:** Node01 account `ubuntu`, password `nvidia` if unchanged or owner credential; key-based SSH to client `ubuntu` accounts and passwordless sudo. WEKA account `admin`, password `Weka.io123` after creation, if cluster status queries request login.

**Expected wait time:** Allow several minutes for client startup and mounts. Actual duration varies; the mount script has no guaranteed total runtime.

```bash
ubuntu@WekaNode01:~$ bash ~/02_mount_clients.sh
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[21-22]' 'hostname; findmnt --mountpoint /mnt/weka; df -h /mnt/weka'
```

Expected: both clients show filesystem type `wekafs`, source `10.200.100.11/default`, mounted at `/mnt/weka`, with approximately 80 GiB capacity. The scripts use `net=udp,num_cores=0` and each client's own data IP.

Write a demo file from Client01, then read it from Client02:

```bash
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.21 'mountpoint -q /mnt/weka && test "$(findmnt -n -o FSTYPE --mountpoint /mnt/weka)" = wekafs && printf "WEKA shared filesystem in DSX Air\n" > /mnt/weka/air-demo.txt && sha256sum /mnt/weka/air-demo.txt'
ubuntu@WekaNode01:~$ ssh ubuntu@192.168.200.22 'mountpoint -q /mnt/weka && test "$(findmnt -n -o FSTYPE --mountpoint /mnt/weka)" = wekafs && cat /mnt/weka/air-demo.txt && sha256sum /mnt/weka/air-demo.txt'
```

Expected: Client02 prints the text written by Client01, and both SHA256 values match. The demo file is overwritten on each run; use a different filename if preserving a previous demonstration. Mounts are session mounts; the script does not create a persistent fstab entry.

### Step 5. Run fio writes and verified reads

**Goal:** Exercise both clients and verify data written by the other client.

**Access needed:** `WekaNode01` with both clients mounted.

**Credentials for this step:** Account `ubuntu`, console password `nvidia` if unchanged or owner credential; key-based SSH and passwordless sudo to the client `ubuntu` accounts.

**Expected wait time:** Several minutes for four sequential jobs; duration depends on actual throughput. If fio is absent, package installation adds time. This is a fixed-size test, not a fixed 30-second run.

```bash
ubuntu@WekaNode01:~$ time bash ~/03_fio_write_read.sh
```

Each client writes its own 1 GiB file with 1 MiB blocks, one job, queue depth eight, libaio, direct I/O, and CRC32C verification metadata. Client01 then reads and verifies Client02's file, and Client02 verifies Client01's file.

Validation: require all jobs to complete with `err=0`, no verification errors, and the final `PASS` message. Logs are saved in a timestamped `weka-fio-*` directory on Node01. Test files remain in a unique `fio-verify-*` directory on the shared filesystem.

Alternate validation:

```bash
ubuntu@WekaNode01:~$ weka status
ubuntu@WekaNode01:~$ ls -dt ~/weka-fio-*
```

Open the appropriate run's `fio.log` to retain write/read results. Do not add separate sequential runs together and label them simultaneous aggregate bandwidth.

### Step 6. Access the WEKA GUI

**Goal:** View the cluster through an Air HTTPS service.

**Access needed:** `oob-mgmt-server`, optionally `WekaNode01` for the fallback relay, then the browser's Air Services panel.

**Credentials for this step:** OOB console account `ubuntu`, password `WekaDsx@123`, or an authorized key for external SSH. Node01 account `ubuntu`, console default `nvidia` if unchanged. GUI account `admin`, password `Weka.io123` after cluster creation unless overridden.

**Expected wait time:** Usually seconds when socat is installed and WEKA is reachable; allow several minutes if the script needs to install the package.

Open the OOB console and run:

```bash
ubuntu@oob-mgmt-server:~$ bash ~/05_oob_gui_service.sh
ubuntu@oob-mgmt-server:~$ sudo systemctl is-active weka-gui-relay
ubuntu@oob-mgmt-server:~$ curl -kI --connect-timeout 5 https://127.0.0.1:14000
```

Expected: relay ready, systemd state `active`, and an HTTP response from WEKA. A login redirect or authentication response establishes HTTP reachability; it is not an authenticated health check. The `-k` flag is used for the lab's self-signed certificate.

If the script reports that Node01's management endpoint is unreachable, open Node01's console and run the fallback:

```bash
ubuntu@WekaNode01:~$ bash ~/05b_node01_gui_relay.sh
ubuntu@WekaNode01:~$ sudo systemctl is-active weka-gui-mgmt-relay
```

Then return to OOB and retry using the fallback port:

```bash
ubuntu@oob-mgmt-server:~$ BACKEND_PORT=14001 bash ~/05_oob_gui_service.sh
ubuntu@oob-mgmt-server:~$ sudo systemctl is-active weka-gui-relay
```

In Air, open **Services → New Service** and enter:

| Field | Value |
|---|---|
| Name | weka-gui |
| Interface | oob-mgmt-server:eth0 |
| Type | HTTPS |
| Service Port | 14000 |

Create the service and open its assigned HTTPS link. If the browser shows a certificate warning, the user must decide whether to acknowledge the lab's self-signed certificate. Log in as `admin` with password `Weka.io123` after cluster creation unless overridden.

Validate that the GUI shows the expected cluster, eight healthy backends, eight available drives, the `default` filesystem, and both connected clients. Capture the GUI only after those checks pass. Do not hardcode a worker hostname or external port in the checkpoint documentation.

### Step 7. Unmount and create a clean checkpoint

**Goal:** Return the simulation to an unconfigured storage state and preserve it for repeatable builds.

**Access needed:** `WekaNode01` for scripts; Air simulation controls for checkpoint saving.

**Credentials for this step:** Ubuntu account `ubuntu`, password `nvidia` if unchanged or owner's current password; prepared SSH keys and passwordless sudo to all ten hosts. The new reset script does not require a WEKA cluster login or UUID.

**Expected wait time:** Unmounts usually take seconds, but busy mounts can fail. Disk reset writes or zeroes and then reads all eight 48 GB data disks; allow substantially more time than a simple container stop. The duration depends on Air storage and is not guaranteed.

First unmount both clients:

```bash
ubuntu@WekaNode01:~$ bash ~/04_unmount_clients.sh
```

Expected: both clients report unmounted. If a mount is busy, stop the workload or leave the mounted directory and retry; the script does not use forced or lazy unmounting.

Preview the destructive reset, then run it only in the simulation whose data you intend to delete:

```bash
ubuntu@WekaNode01:~$ bash ~/00_teardown.sh --plan
ubuntu@WekaNode01:~$ time bash ~/00_teardown.sh --apply
```

The reset checks host identities and known containers, stops all containers, removes backend/client state, then waits for the data disks to return to Linux. It identifies `weka01`–`weka08` by serial, validates all eight disks before starting any wipe, and verifies full-device zeroing. Root disks and swap are preserved.

Validation: require eight disk `PASS` messages and `RESET COMPLETE`. If reset stops early, retain the log and do not save that partial state as the clean checkpoint.

Before stopping the simulation, inspect the empty local container lists:

```bash
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[11-18],192.168.200.[21-22]' 'hostname; sudo -n weka local ps'
```

In Air, stop the simulation with checkpoint saving enabled and wait for saving to finish. Open **Checkpoints** and identify the newly saved clean checkpoint. Record it as `WEKA-5.1.34-8Backend-Clean-Ready` in the demo name/description or checkpoint label if the UI supports labeling. Preserve it as a favorite when appropriate. Do this before building another cluster.

To test it, use the checkpoint selection next to **Start Simulation**, or launch the published Marketplace demo that selects this clean checkpoint. Confirm the starting state with Step 1 and repeat Steps 2–6. Check external service mappings for that launch; the previous URL may no longer be the correct one.

<!-- AIR:page -->

## Validation Summary

| Check | Passing condition |
|---|---|
| Prepared environment | Correct hostnames, WEKA 5.1.34, scripts present, key-based SSH/sudo working |
| Data network | All ten MTUs 9000; successful jumbo pings to all nine peers from Node01 |
| Backend health | Eight containers and eight drives UP; I/O STARTED |
| Protection | 5+2 fully protected, one hot-spare failure domain |
| Filesystem | default, group1, approximately 80 GiB |
| Client access | Both clients show an actual wekafs mount at /mnt/weka |
| Shared data | Client02 reads Client01's text; SHA256 checksums match |
| fio verification | Four jobs complete without errors and final PASS appears |
| GUI | Air HTTPS link reaches GUI; expected health/filesystem/client state visible after login |
| Clean reset | Eight full-disk PASS results, RESET COMPLETE, no containers remain |
| Checkpoint test | Restored clean starting state; creation, mounting and verification pass again |

Previously supplied CLI output confirmed an eight-backend/eight-drive healthy cluster with 5+2 protection and a successful full-disk reset. The OOB script also reported a ready relay. These observations do not substitute for checking the current launch. The complete new fio verification result, external GUI screenshot, and newest clean-checkpoint cycle were not all supplied as evidence when this guide was written.

## Troubleshooting, Upgrade, or Reset

### Cluster creation stops during preflight

Read the timestamped build log before rerunning. Check software version, eth1 addresses, MTU, SSH/sudo, container state, disk serials, and data-disk signatures. The corrected script allows active swap. A cluster already configured on the checkpoint is not a clean starting state.

### CLI authentication fails

On Node01, use WEKA account `admin` with password `Weka.io123` after creation unless overridden:

```bash
ubuntu@WekaNode01:~$ weka user login
ubuntu@WekaNode01:~$ weka status
```

Ubuntu and root can have different WEKA login profiles. Logging in as ubuntu does not authenticate root; the creation script logs in both profiles automatically. The new reset script uses local container controls and does not require a cluster-status login or a hardcoded UUID.

### Data NVMe disappears from lsblk

Active WEKA can own the controller through `igb_uio`. This was observed on all eight data controllers in this lab. Do not interpret the missing Linux device alone as a missing virtual disk, and do not rebind a controller while WEKA is using it.

```bash
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[11-18]' 'hostname; sudo -n lspci -nnk -d ::0108'
```

Reset stops/removes the containers before validating the returned Linux disks. If a serial does not return, it aborts before wiping; retain logs for the owner to investigate.

### GUI link fails

From OOB, confirm the relay and backend reachability:

```bash
ubuntu@oob-mgmt-server:~$ sudo systemctl status weka-gui-relay --no-pager
ubuntu@oob-mgmt-server:~$ sudo journalctl -u weka-gui-relay -n 30 --no-pager
ubuntu@oob-mgmt-server:~$ curl -kI --connect-timeout 5 https://192.168.200.11:14000
```

If management HTTPS is unreachable but data HTTPS works on Node01, use the Step 6 fallback relay. Check the Air interface, HTTPS service type, internal port 14000, and current assigned URL. If the cluster has been torn down, the GUI backend is unavailable until cluster creation succeeds again.

### Restored cluster reports unknown or failed drives

A prior checkpoint of the running configured cluster restored with eight backend containers but no usable drives. The cause and additional NVMe state guarantees were not established. Use the tested clean starting point and create a fresh cluster rather than assuming an existing filesystem was restored consistently. If data must be preserved, stop destructive actions and contact the owner with status, alerts, drive list, disk inventory, and checkpoint details.

### Client memory alerts or licensing warnings

Inspect current alerts and client memory:

```bash
ubuntu@WekaNode01:~$ weka alerts
ubuntu@WekaNode01:~$ PDSH_RCMD_TYPE=ssh pdsh -l ubuntu -w '192.168.200.[21-22]' 'hostname; free -h'
```

Eight-GiB clients previously showed low available-memory alerts. Increasing client memory is an optional topology change and consumes more Air quota. Obtain an appropriate WEKA license through the owner; do not interpret a missing license as a validated production deployment.

### Upgrade

This guide targets WEKA 5.1.34. An upgrade workflow is not included. Coordinate image/software changes with the lab owner and repeat validation before publishing a changed demo.

## References

- [NVIDIA DSX Air Quick Start](https://docs.nvidia.com/dsx-air/quick-start/)
- [NVIDIA DSX Air Simulation Management](https://docs.nvidia.com/dsx-air/simulation-management/)
- [NVIDIA DSX Air](https://dsx-air.nvidia.com/)
- Partner repository, plain text: `github.com/weka/weka-dsx-air-demo` (access depends on WEKA repository permissions).
- Partner documentation titles: WEKA 5.1 CLI Reference Guide; WEKA Filesystem Client Mount Guide. Request access from the WEKA lab owner.

Partner resources are named without live external links to follow this Air guide template's publishing format. Include this guide directly in the demo so NVIDIA reviewers do not depend on private repository access.

## Contact Info

| Contact type | Contact details |
|---|---|
| WEKA lab handoff | Bob and the WEKA technical alliances team; request the current lab owner through your WEKA contact |
| Scripts and lab documentation | WEKA-owned repository named above; access provided by the repository owner |
| NVIDIA DSX Air validation | David Zenone and the NVIDIA DSX Air TME team through the existing project thread |
| Air account/resource access | Your organization's Air administrator |

When requesting help, include the simulation name, selected checkpoint, failed step, timestamped logs, and read-only status/alert output. Exclude passwords, private keys, tokens, and license secrets.
