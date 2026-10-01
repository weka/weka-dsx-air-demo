# Update the existing GitHub repository

The existing repository is `sekharg-weka/weka-dsx-air-demo`. The Mac checkout is `~/Downloads/weka-dsx-air-demo`; `gh` is authenticated as `sekharg-weka`. The five-node screenshot was pushed in commit f258af1. This update prepares the validated eight-node guide, supplied topology screenshot, corrected build/continuation scripts, inventory, and validation notes. It does not create a second repository or change visibility.

After downloading WEKA_8Node_Repo_Update.zip, use the Mac Terminal:

```bash
cd ~/Downloads
unzip -o WEKA_8Node_Repo_Update.zip
cd ~/Downloads/weka-dsx-air-demo
git pull --ff-only
python3 ../weka-8node-repo-update/apply_update.py .
python3 scripts/check_repository.py
git diff --stat
git add README.md docs/publishing.md docs/script-guide.md docs/validation-record.md labs/8node
git commit -m "Document validated eight-node WEKA DSX Air lab"
git push origin main
```

The updater checks the origin repository and refuses to overwrite uncommitted changes in its target files. It backs up replaced files outside the checkout, then copies only its declared payload. Review the changes before committing. If pull or the updater fails, stop and resolve that reported condition rather than forcing it.

Repository-local author identity supplied by the owner:

```bash
git config user.name "Chandra Sekhar Gonuguntla"
git config user.email "chandrasekhar.gonuguntla@weka.io"
```

GitHub publication is separate from an NVIDIA-hosted catalog submission. No WEKA installer credential, license, private key, or VM image is part of this update. No new license terms are assigned.
