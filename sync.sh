#!/bin/bash
# Syncs YAML configs from vbet-partner-app to yaml-server and pushes to GitHub
# Usage: ./sync.sh [commit message]

set -e

SRC="/Users/darkdezert/Desktop/flutter/vbet-partner-app/lib/yaml_ui_integration/yaml_server/api"
DST="/Users/darkdezert/Desktop/flutter/yaml-server/api"
MSG="${1:-update yaml configs}"

echo "🔄 Syncing YAML files..."
cp -r "$SRC/." "$DST/"

echo "📦 Committing..."
cd "$(dirname "$0")"
git add .
git diff --cached --quiet && echo "✅ No changes to push" && exit 0

git commit -m "$MSG"
git push

echo "✅ Done! Changes are live on GitHub."
