# GitHub and Marketplace handoff

Existing private repository: https://github.com/sekharg-weka/weka-dsx-air-demo

Apply the prepared update to a clean checkout, run checks, review the diff, commit and push. Keep the repo private unless its owner authorizes a visibility change. For durable team ownership, the owner can transfer it to the appropriate WEKA GitHub organization and grant Bob/team access; neither transfer nor permissions are automated by this package.

```bash
python3 scripts/check_repository.py
for f in labs/8node/scripts/*.sh; do bash -n "$f" || exit; done
git diff --stat
git add -A
git commit -m "Add clean-checkpoint eight-node WEKA demo workflow"
git push origin main
```

For a genuinely new private repository, use scripts/publish_github.sh with the intended GitHub owner. It refuses an existing repo. Configure your Git author identity before committing.

Marketplace documentation should be included in the published demo so NVIDIA reviewers do not depend on private GitHub access. Use the verified clean checkpoint, retain internal visibility as appropriate, and provide the actual demo link after publication. No successful new Marketplace publish is asserted here.
