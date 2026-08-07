#!/bin/sh
#
# Point git at the versioned hooks in .githooks/ and make them executable.
# Run once after cloning:  ./scripts/install-hooks.sh
#
set -eu

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

chmod +x .githooks/pre-commit .githooks/commit-msg
git config core.hooksPath .githooks

echo "✓ Installed git hooks (core.hooksPath = .githooks)."
echo "  • pre-commit  → formats staged Swift files with swift-format"
echo "  • commit-msg  → enforces Conventional Commits + agent model attribution"
