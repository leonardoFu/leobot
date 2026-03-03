#!/bin/bash
set -euo pipefail

# sync-upstream.sh — Sync leobot fork with upstream nanoclaw, then rebrand
#
# Usage:
#   ./scripts/sync-upstream.sh          # merge upstream/main
#   ./scripts/sync-upstream.sh rebase   # rebase onto upstream/main
#
# What it does:
#   1. Ensures 'upstream' remote points to qwibitai/nanoclaw
#   2. Fetches latest upstream
#   3. Merges (or rebases) upstream/main into current branch
#   4. Runs rebrand.sh to re-apply LeoBot branding
#   5. Commits the rebrand changes
#   6. Optionally pushes to origin

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UPSTREAM_URL="https://github.com/qwibitai/nanoclaw.git"
UPSTREAM_BRANCH="main"
MODE="${1:-merge}"  # merge or rebase

echo "🔄 LeoBot Upstream Sync"
echo "   Mode: $MODE"
echo ""

# --- Step 1: Ensure clean working tree ---
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ Working tree is dirty. Commit or stash changes first."
  exit 1
fi

# --- Step 2: Ensure upstream remote ---
if ! git remote get-url upstream &>/dev/null; then
  echo "📡 Adding upstream remote: $UPSTREAM_URL"
  git remote add upstream "$UPSTREAM_URL"
else
  CURRENT_URL=$(git remote get-url upstream)
  if [ "$CURRENT_URL" != "$UPSTREAM_URL" ]; then
    echo "📡 Updating upstream remote: $UPSTREAM_URL"
    git remote set-url upstream "$UPSTREAM_URL"
  fi
fi

# --- Step 3: Fetch upstream ---
echo "⬇️  Fetching upstream..."
git fetch upstream

# --- Step 4: Get current branch ---
CURRENT_BRANCH=$(git branch --show-current)
echo "   Current branch: $CURRENT_BRANCH"

# --- Step 5: Check if there are new commits ---
LOCAL_HEAD=$(git rev-parse HEAD)
UPSTREAM_HEAD=$(git rev-parse "upstream/$UPSTREAM_BRANCH")
MERGE_BASE=$(git merge-base HEAD "upstream/$UPSTREAM_BRANCH")

if [ "$UPSTREAM_HEAD" = "$MERGE_BASE" ]; then
  echo "✅ Already up to date with upstream. Nothing to do."
  exit 0
fi

NEW_COMMITS=$(git log --oneline "$MERGE_BASE..$UPSTREAM_HEAD" | wc -l | tr -d ' ')
echo "   📦 $NEW_COMMITS new upstream commit(s)"
echo ""

# --- Step 6: Merge or rebase ---
if [ "$MODE" = "rebase" ]; then
  echo "🔀 Rebasing onto upstream/$UPSTREAM_BRANCH..."
  if ! git rebase "upstream/$UPSTREAM_BRANCH"; then
    echo ""
    echo "⚠️  Rebase conflict! Resolve conflicts, then run:"
    echo "   git rebase --continue"
    echo "   ./scripts/rebrand.sh"
    exit 1
  fi
else
  echo "🔀 Merging upstream/$UPSTREAM_BRANCH..."
  if ! git merge "upstream/$UPSTREAM_BRANCH" --no-edit -m "Sync with upstream nanoclaw $(date +%Y-%m-%d)"; then
    echo ""
    echo "⚠️  Merge conflict! Resolve conflicts, then run:"
    echo "   git add -A && git commit"
    echo "   ./scripts/rebrand.sh"
    exit 1
  fi
fi

echo "  ✅ $MODE complete"
echo ""

# --- Step 7: Re-apply rebrand ---
echo "🎨 Re-applying LeoBot branding..."
bash "$ROOT/scripts/rebrand.sh"

# --- Step 8: Commit rebrand if there are changes ---
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "Rebrand: re-apply LeoBot branding after upstream sync"
  echo ""
  echo "✅ Rebrand committed"
else
  echo ""
  echo "✅ No rebrand changes needed (upstream didn't introduce new references)"
fi

# --- Step 9: Push prompt ---
echo ""
read -p "Push to origin/$CURRENT_BRANCH? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if [ "$MODE" = "rebase" ]; then
    git push origin "$CURRENT_BRANCH" --force-with-lease
  else
    git push origin "$CURRENT_BRANCH"
  fi
  echo "🚀 Pushed to origin/$CURRENT_BRANCH"
else
  echo "⏭️  Skipped push. Run: git push origin $CURRENT_BRANCH"
fi

echo ""
echo "🎉 Sync complete!"
