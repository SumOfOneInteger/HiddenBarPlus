# Homebrew cask for Hidden Bar Plus.
#
# Lives here until the first notarized release, then goes into a tap
# (SumOfOneInteger/homebrew-tap) or homebrew/homebrew-cask; see docs/RUNBOOK.md.
# `scripts/update-cask.sh <version>` fills in version and sha256 for a release.
cask "hidden-bar-plus" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/SumOfOneInteger/HiddenBarPlus/releases/download/v#{version}/HiddenBarPlus-#{version}.zip"
  name "Hidden Bar Plus"
  desc "Hide menu bar items, including on macOS 27"
  homepage "https://github.com/SumOfOneInteger/HiddenBarPlus"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Hidden Bar Plus.app"

  uninstall quit:       "com.sumofoneinteger.hiddenbarplus",
            login_item: "Hidden Bar Plus"

  zap trash: [
    "~/Library/Application Support/com.sumofoneinteger.hiddenbarplus",
    "~/Library/Caches/com.sumofoneinteger.hiddenbarplus",
    "~/Library/HTTPStorages/com.sumofoneinteger.hiddenbarplus",
    "~/Library/Preferences/com.sumofoneinteger.hiddenbarplus.plist",
  ]
end
