#!/bin/bash
set -e

# --- Configuration ---
UPSTREAM_URL="https://github.com/yeagerghost/deecourse.git"
VENDOR_BRANCH="vendor"
CUSTOM_BRANCH="main"
UPSTREAM_REMOTE="upstream"

echo "🔍 Starting sync process..."

# 1. Safety Check: Uncommitted Changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Error: You have uncommitted changes. Please commit or stash them."
  exit 1
fi

# 2. Remote Verification & Setup
CURRENT_UPSTREAM=$(git remote get-url $UPSTREAM_REMOTE 2>/dev/null || echo "")
if [ "$CURRENT_UPSTREAM" != "$UPSTREAM_URL" ]; then
  if [ -z "$CURRENT_UPSTREAM" ]; then
    echo "➕ Adding upstream remote..."
    git remote add $UPSTREAM_REMOTE "$UPSTREAM_URL"
  else
    echo "⚠️ Updating upstream URL..."
    git remote set-url $UPSTREAM_REMOTE "$UPSTREAM_URL"
  fi
fi

# 3. Fetch all remotes
echo "📡 Fetching updates from all remotes..."
git fetch --all

# --- NEW SECTION: Ensure local vendor branch exists ---
if ! git rev-parse --verify $VENDOR_BRANCH >/dev/null 2>&1; then
  echo "Branch '$VENDOR_BRANCH' not found locally. Checking origin..."
  if git rev-parse --verify origin/$VENDOR_BRANCH >/dev/null 2>&1; then
    git checkout -b $VENDOR_BRANCH origin/$VENDOR_BRANCH
  else
    echo "❌ Error: Branch '$VENDOR_BRANCH' does not exist locally or on origin."
    exit 1
  fi
fi

# 4. Compare Vendor Branch with Upstream/Main
echo "--- 📊 Change Summary ($VENDOR_BRANCH vs $UPSTREAM_REMOTE/main) ---"
# We use fetch first to make sure upstream/main is known
NEW_COMMITS=$(git log $VENDOR_BRANCH..$UPSTREAM_REMOTE/main --oneline)

if [ -z "$NEW_COMMITS" ]; then
  echo "✅ Your $VENDOR_BRANCH branch is already up to date."
else
  echo "The following upstream changes will be pulled:"
  echo "$NEW_COMMITS"
  echo "------------------------------------------------------"

  # 5. Update the Vendor Branch
  echo "🔄 Updating local '$VENDOR_BRANCH'..."
  git checkout $VENDOR_BRANCH
  git merge $UPSTREAM_REMOTE/main --ff-only || git merge $UPSTREAM_REMOTE/main

  echo "📤 Pushing updated $VENDOR_BRANCH to origin..."
  git push origin $VENDOR_BRANCH

  # 6. Integrate into Custom Main
  echo "🔀 Merging $VENDOR_BRANCH into $CUSTOM_BRANCH..."
  git checkout $CUSTOM_BRANCH
  git merge $VENDOR_BRANCH -m "chore: sync latest upstream updates from vendor branch"

  echo "✨ Success! Latest vendor changes merged into $CUSTOM_BRANCH."
  echo "🚀 To finish, run: git push origin $CUSTOM_BRANCH"
fi
