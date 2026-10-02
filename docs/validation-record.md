# Validation record

Evidence supplied by the lab owner during October 1, 2026 testing:

- WEKA 5.1.34; eight backend containers and eight drives UP; 5+2 fully protected; one hot-spare failure domain.
- Reported usable capacity 198.56 GiB, with an 80 GiB filesystem allocated.
- All ten hosts reported eth1 MTU 9000; key-based management SSH and sudo worked.
- Initial failed checkpoint instance was reset: all eight 48,000,000,000-byte data disks passed full zero readback; RESET COMPLETE reported. Root and swap were retained.
- Rebuilt cluster status later showed all eight drives healthy; latest shown UUID was 2208a238-124d-4118-af81-214368a42518. UUID is a historical observation, not a teardown requirement.
- Active data controllers were observed bound to igb_uio on all eight hosts, while swap controllers used nvme. Reset now defers Linux disk checks until containers are removed and finds disks by serial.
- OOB GUI setup reported relay ready. Successful external browser GUI access was not supplied as evidence.

The owner showed fio log directories, but complete output proving the new cross-client CRC32C verification was not supplied here. Do not describe this specific test as passed until its final PASS and logs are captured.

The newest generic reset script has passed local Bash syntax checks; its full Air run has not been confirmed. A running-cluster checkpoint restored with zero usable WEKA drives; the cause and additional-NVMe checkpoint guarantees remain unresolved. The corrected complete clean-checkpoint restore workflow needs recorded end-to-end validation.

This lab is unlicensed. Current credentials and TLS/other alerts must be reviewed from the actual instance. Simulated I/O results are not production performance measurements.
