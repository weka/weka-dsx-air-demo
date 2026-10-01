# Publish from a Mac

Proposed repository name: `weka-dsx-air-demo`. This package has not yet been published to GitHub.

1. Extract the repository ZIP into Downloads.
2. Install the GitHub CLI if needed and authenticate through its normal browser login. Never paste tokens into scripts or chat.
3. From the extracted `weka-dsx-air-demo` folder, run:

```bash
python3 scripts/check_repository.py
bash scripts/publish_github.sh YOUR_GITHUB_OWNER
```

Replace YOUR_GITHUB_OWNER with the account or organization that should own the new repository. The script creates a **private** repository, checks for an existing repo before proceeding, and pushes the initial commit. It does not overwrite an existing repository. Change visibility through GitHub only when ready to share publicly.

If you prefer browser upload, create an empty private repository named `weka-dsx-air-demo`, then upload the contents of this directory. GitHub CLI upload is better for preserving executable flags and the directory tree.

No license was assigned automatically. Confirm the intended license and ownership before making the repository public. WEKA binaries, licenses, private keys, and VM archives are excluded.
