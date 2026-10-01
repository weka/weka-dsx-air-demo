# Five-node provisioning reference

The `.sh.txt` file is the original rebuild script extracted from the supplied console transcript. It is stored as text so it is not a numbered setup step.

It removes WEKA containers and wipes `/dev/nvme0n1` and `/dev/nvme1n1`; running it destroys the existing lab data. It assumes WEKA is installed, working sudo/SSH, fixed disk numbering, and cluster container IDs 0–4. It disables SSH host-key checks and ignores some errors. Review these assumptions before any use. It targets five backends only.

The later supplied result confirmed five containers/drives UP, I/O STARTED, 3+2 fully protected, and two connected clients. That result validates the reported lab, not every script path. There is no validated eight-node rebuild script in this repository.

## Additional build script excerpt

`02_create_5backend_2client_weka_demo.sh.txt` is the newer supplied transcript excerpt, preserved as received. It begins with `et -euo pipefail` rather than `set -euo pipefail` and lacks a shebang in the pasted excerpt. Confirm the actual source file before attempting to execute it. It includes an optional WEKA_INSTALL_URL installer flow, different container/core settings, failure-domain labels, a group1/20GiB filesystem default, and different cluster-create syntax from the later UDP rebuild. These scripts are alternative historical paths, not consecutive numbered stages. Do not combine them without release-specific CLI review. No installer URL or credentials are embedded in this repository.

`labs/5node/storage.5` is the confirmed backend-only IP list. `labs/8node/storage.8` is the planned extension; it excludes client and switch addresses. Neither file initializes a cluster by itself.

## UDP client setup source

`03_setup_clients_only_udp.sh.txt` is the supplied client setup script, preserved as text. It configures both clients, optionally installs WEKA using a supplied installer URL, unmounts/removes old client state, mounts with `net=udp,num_cores=0,mgmt_ip=...`, and runs fio sequentially. It is not a read-only validation helper. It assumes `nc` exists but does not explicitly install netcat; confirm that dependency before use. It suppresses errors in some mount verification commands. The client addresses remain .21/.22 for either backend count; keeping the lead backend at .11 does not itself commission an eight-node cluster.

Other scripts listed on the VM have not been supplied in full: 03_setup_clients_only.sh, its .bak, teardown.sh, and clean_teardown_dsx_weka.sh. The repo does not invent those contents. Import them from the archive once export is complete.
