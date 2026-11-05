#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
destination="${1:-$project_dir/dist}"
cd "$project_dir"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app_path="$destination/折叠栏.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/NotchShelf" "$app_path/Contents/MacOS/NotchShelf"
cp Info.plist "$app_path/Contents/Info.plist"
cp LICENSE THIRD_PARTY.md "$app_path/Contents/Resources/"
codesign --force --sign - --identifier local.eugene.NotchShelf --requirements '=designated => identifier "local.eugene.NotchShelf"' "$app_path"
codesign --verify --deep --strict "$app_path"
printf 'Built: %s\n' "$app_path"
