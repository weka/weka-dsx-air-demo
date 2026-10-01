# Publishing the standard eight-node lab

Repository: `sekharg-weka/weka-dsx-air-demo`. The standard topology is eight backends, two clients, and one virtual Cumulus switch. The local Mac checkout is `~/Downloads/weka-dsx-air-demo`.

After applying the prepared standard-topology update, validate and publish from the repository root:

```bash
python3 scripts/check_repository.py
git diff --stat
git add -A
git commit -m "Standardize WEKA DSX Air demo on eight backends"
git push origin main
```

The update utility requires a clean checkout, checks the origin repository, and backs up replaced and removed files outside the checkout. It does not change visibility or create another repository.

Repository-local author identity:

```bash
git config user.name "Chandra Sekhar Gonuguntla"
git config user.email "chandrasekhar.gonuguntla@weka.io"
```

GitHub publication is separate from an NVIDIA-hosted lab catalog submission. No installer credentials, licenses, private keys, or VM images are included. No new license terms are assigned.
