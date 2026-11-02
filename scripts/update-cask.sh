#!/bin/bash
# Point Casks/hidden-bar-plus.rb at a release: sets version and sha256.
#
#   scripts/update-cask.sh 1.0.0                      # downloads the GitHub release asset
#   scripts/update-cask.sh 1.0.0 build/HiddenBarPlus-1.0.0.zip   # uses a local zip
#
# Then test locally with:  brew install --cask ./Casks/hidden-bar-plus.rb
set -euo pipefail

version="${1:?usage: $0 <version> [path/to/HiddenBarPlus-<version>.zip]}"
zip="${2:-}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cask="$repo_root/Casks/hidden-bar-plus.rb"

if [ -z "$zip" ]; then
  tmp="$(mktemp -d)"
  zip="$tmp/HiddenBarPlus-$version.zip"
  url="https://github.com/SumOfOneInteger/HiddenBarPlus/releases/download/v$version/HiddenBarPlus-$version.zip"
  echo "downloading $url"
  curl -fsSL -o "$zip" "$url"
fi

sha="$(shasum -a 256 "$zip" | cut -d' ' -f1)"

# macOS sed needs the empty suffix for in-place edits.
sed -i '' \
  -e "s/^  version \".*\"/  version \"$version\"/" \
  -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
  "$cask"

grep -nE '^  (version|sha256) ' "$cask"
echo "updated $cask"
echo "next: brew install --cask \"$cask\"   # then commit, and copy to your tap"
