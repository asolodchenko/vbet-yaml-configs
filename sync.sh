#!/bin/bash
# Syncs SCREEN YAML configs from vbet-partner-app to yaml-server and pushes to GitHub
# NOTE: api/config/ (router, theme) is NOT synced — edit those files directly in yaml-server/
# Usage: ./sync.sh [commit message]

set -e

SRC="/Users/darkdezert/Desktop/flutter/vbet-partner-app/lib/yaml_ui_integration/yaml_server/api/screens"
DST="/Users/darkdezert/Desktop/flutter/yaml-server/api/screens"
MSG="${1:-update yaml configs}"

echo "🔄 Syncing screen YAML files..."
cp -r "$SRC/." "$DST/"

echo "📦 Committing..."
cd "$(dirname "$0")"
git add api/screens/
git diff --cached --quiet && echo "✅ No changes to push" && exit 0

git commit -m "$MSG"
git push

echo "✅ Done! Changes are live on GitHub."
