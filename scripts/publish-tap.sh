#!/bin/bash
# Copy Casks/hidden-bar-plus.rb into the SumOfOneInteger/homebrew-tap repository
# and push it. The release workflow does the same when HOMEBREW_TAP_TOKEN is set;
# this is the manual path.
#
#   scripts/publish-tap.sh                    # uses/creates a clone at ~/GitHub/homebrew-tap
#   scripts/publish-tap.sh /path/to/homebrew-tap
#
# The tap repository must exist on GitHub first (an empty repo named
# "homebrew-tap" under your account); homebrew-tap/README.md in this repo is its README.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tap="${1:-$HOME/GitHub/homebrew-tap}"
owner="SumOfOneInteger"
cask="$repo_root/Casks/hidden-bar-plus.rb"

version="$(sed -nE 's/^  version "(.*)"/\1/p' "$cask")"
sha="$(sed -nE 's/^  sha256 "(.*)"/\1/p' "$cask")"
if [ "$sha" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
  echo "the cask still has the placeholder sha256; run scripts/update-cask.sh $version first" >&2
  exit 1
fi

if [ ! -d "$tap/.git" ]; then
  git clone "https://github.com/$owner/homebrew-tap.git" "$tap"
fi

mkdir -p "$tap/Casks"
cp "$cask" "$tap/Casks/hidden-bar-plus.rb"
[ -f "$tap/README.md" ] || cp "$repo_root/homebrew-tap/README.md" "$tap/README.md"

git -C "$tap" add Casks/hidden-bar-plus.rb README.md
if git -C "$tap" commit -m "hidden-bar-plus $version"; then
  git -C "$tap" push
else
  echo "tap already up to date"
fi
echo "install with: brew install --cask $(echo "$owner" | tr '[:upper:]' '[:lower:]')/tap/hidden-bar-plus"
