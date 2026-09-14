#!/usr/bin/env bash
# Lint every Markdown file the way CI does: markdownlint-cli2 at a pinned
# version (an unpinned npx would follow the rolling latest and could turn CI
# red on untouched docs), configured by .markdownlint.json. Build output and
# checkouts under Packages are skipped.
set -euo pipefail
cd "$(dirname "$0")/.."
MARKDOWNLINT_VERSION=0.23.2
command -v npx >/dev/null || { echo "error: npx (Node) not found — needed for markdownlint." >&2; exit 1; }
npx --yes "markdownlint-cli2@${MARKDOWNLINT_VERSION}" \
    "**/*.md" "#.build" "#.build-xcode" "#Packages/**/.build" "#node_modules" "#dist"
