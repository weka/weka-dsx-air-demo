#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
owner="${1:-}"
if [[ -z "$owner" || ! "$owner" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
  echo "Usage: bash scripts/publish_github.sh YOUR_GITHUB_OWNER" >&2
  exit 1
fi
command -v gh >/dev/null || { echo "GitHub CLI is required. Install gh, then run gh auth login." >&2; exit 1; }
gh auth status
python3 scripts/check_repository.py
if gh repo view "$owner/weka-dsx-air-demo" >/dev/null 2>&1; then
  echo "Repository already exists; no changes made. Use its normal reviewed update workflow." >&2
  exit 1
fi
if [[ -d .git ]]; then
  echo "Existing Git checkout detected. Refusing to replace its publishing configuration." >&2
  exit 1
fi
git var GIT_AUTHOR_IDENT >/dev/null
git init -b main
git add .
git commit -m "Add standard eight-backend WEKA DSX Air lab"
gh repo create "$owner/weka-dsx-air-demo" --private --source=. --remote=origin --push --description "Standard eight-backend WEKA lab for NVIDIA DSX Air"
gh repo view "$owner/weka-dsx-air-demo" --json url --jq .url
