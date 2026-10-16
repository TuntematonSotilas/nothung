#!/usr/bin/env bash
# Installs the pinned gdUnit4 version into game/addons/gdUnit4 (git-ignored).
# Run once after cloning, and again after changing GDUNIT4_VERSION.
# Works on Linux, macOS and Git Bash on Windows. Requires curl and tar.
# See docs/technical/09-testing.md#framework.
set -euo pipefail

GDUNIT4_VERSION="6.2.2"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$repo_root/game/addons/gdUnit4"

installed="$(sed -n 's/^version="\(.*\)"$/\1/p' "$target/plugin.cfg" 2>/dev/null || true)"
if [ "$installed" = "$GDUNIT4_VERSION" ]; then
	echo "gdUnit4 $GDUNIT4_VERSION already installed."
	exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Downloading gdUnit4 $GDUNIT4_VERSION..."
curl -fsSL -o "$work/gdunit4.tar.gz" \
	"https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v$GDUNIT4_VERSION.tar.gz"

# Extract from inside the temp folder: GNU tar on Windows misreads "C:/..." archive paths as remote hosts.
(cd "$work" && tar -xzf gdunit4.tar.gz)
source_dir="$work/gdUnit4-$GDUNIT4_VERSION/addons/gdUnit4"
if [ ! -f "$source_dir/plugin.cfg" ]; then
	echo "error: addons/gdUnit4 not found in the v$GDUNIT4_VERSION archive" >&2
	exit 1
fi

rm -rf "$target"
mkdir -p "$(dirname "$target")"
cp -R "$source_dir" "$target"
echo "gdUnit4 $GDUNIT4_VERSION installed in game/addons/gdUnit4."
