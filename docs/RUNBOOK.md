# Maintainer runbook

Build, verify and release Hidden Bar Plus. Assumes current Xcode on macOS 13+.

## Build

```sh
# CI-style build, no signing required
xcodebuild -project 'Hidden Bar Plus.xcodeproj' -scheme 'Hidden Bar Plus' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build

# unit tests: HiddenBarTests (engines, autostart) and HiddenTests (notch overflow,
# hosted inside the app)
xcodebuild -project 'Hidden Bar Plus.xcodeproj' -scheme 'Hidden Bar Plus' \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

# runnable local build: pass your team once, or set it in Xcode under
# Signing & Capabilities (the project ships with no DEVELOPMENT_TEAM)
xcodebuild -project 'Hidden Bar Plus.xcodeproj' -scheme 'Hidden Bar Plus' \
  -configuration Debug DEVELOPMENT_TEAM=XXXXXXXXXX -allowProvisioningUpdates build
```

The CI workflow in `.github/workflows/ci.yml` runs exactly these two commands
on a GitHub-hosted macOS runner for every push and pull request.

There are two configurations, `Debug` and `Release`, and both compile the
macOS 27 native hiding engine (`HIDDENBAR_NATIVE_VISIBILITY` is always set).
Both must exit 0 with **no** `MACOSX_DEPLOYMENT_TARGET` override; the floor is
13.0 in the project file. The single expected warning is the deliberately
deprecated `SMLoginItemSetEnabled(false)` call that cleans up legacy Hidden Bar
login items. The first build resolves the HotKey and Sparkle packages.

## Behavioral verification

Unit tests cover the engines and preferences; the menu bar itself is verified
by hand or by script against the real thing:

1. **Truth signal on macOS 13–26**: the separator's AX size.
   `osascript -e 'tell application "System Events" to tell process "Hidden Bar Plus" to get size of menu bar item 2 of menu bar 2'`
   reads ~20pt expanded vs ~2x-screen-width collapsed. Item 1 is the arrow. On
   macOS 27 the separator is not in the bar; check that icons left of the arrow
   disappear on collapse instead.
2. **Real clicks, not AXPress**: `AXPress` on the arrow is a no-op because the
   action handler reads `NSApp.currentEvent` (nil under assistive synthesis;
   known accessibility defect). Post real `CGEvent` mouse clicks at the arrow's
   AX-reported coordinates instead.

Standard checks before any release:

- expand/collapse toggle works both ways;
- with `numberOfSecondForAutoHide` set to 3, an expanded bar survives 2x the
  window while the pointer is parked in the menubar band, collapses within the
  window once the pointer leaves, and collapses normally if the pointer never
  entered;
- `hoverToExpand` off: hover does nothing; on: dwell expands;
- autostart pref on -> `AutoStart: SMAppService.mainApp.status = 1` on stderr;
  off -> `= 0` (run the binary directly to capture stderr);
- *Check for Updates…* in the context menu is enabled in a signed build with
  `SUPublicEDKey` set, and reports "up to date" against the live appcast;
- localization tables stay parseable: `plutil -lint hidden/*.lproj/*.strings`.

When testing on a machine that runs the app daily: export the prefs domain
first (`defaults export com.sumofoneinteger.hiddenbarplus backup.plist`), quit
the installed app, test the dev build, then re-import and relaunch.

## Release

### One-time setup

1. **Apple Developer Program** membership. Create a *Developer ID Application*
   certificate (Xcode > Settings > Accounts > Manage Certificates) and store
   notarization credentials once:
   `xcrun notarytool store-credentials notary --apple-id you@example.com --team-id XXXXXXXXXX`
   (uses an app-specific password from appleid.apple.com).
2. **Sparkle signing keys.** The tools ship inside the resolved package:

   ```sh
   SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -type d \
     -path '*artifacts/sparkle/Sparkle/bin' | head -1)
   "$SPARKLE_BIN/generate_keys"
   ```

   It prints the public key and stores the private key in your login keychain.
   Put the public key in `hidden/Info.plist` as `SUPublicEDKey` (replace the
   comment there). Export a backup with `generate_keys -x sparkle_private.key`
   and keep it somewhere safe: losing the private key strands every installed
   copy, because they will refuse updates signed with a new key.
3. **Appcast hosting.** `SUFeedURL` in `Info.plist` is
   `https://sumofoneinteger.github.io/HiddenBarPlus/appcast.xml`. Enable GitHub
   Pages for this repository (a `gh-pages` branch or `docs/` folder) and publish
   `appcast.xml` there, or change the URL before the first release. It must
   stay HTTPS and must never move once users have the app.
4. Fill in `teamID` in `scripts/ExportOptions.plist`.

### Each release

1. Verify: builds green, tests green, behavioral checks above run, CHANGELOG
   has the entry.
2. Bump `MARKETING_VERSION` (what users see, e.g. 1.0.1) and
   `CURRENT_PROJECT_VERSION` (an integer that must increase every release;
   Sparkle compares it) in the project file, in both configurations.
3. Archive and export a Developer ID build:

   ```sh
   xcodebuild -project 'Hidden Bar Plus.xcodeproj' -scheme 'Hidden Bar Plus' \
     -configuration Release -archivePath build/HiddenBarPlus.xcarchive \
     -allowProvisioningUpdates archive
   xcodebuild -exportArchive -archivePath build/HiddenBarPlus.xcarchive \
     -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/export
   ```

   (Or Product > Archive in Xcode, then *Distribute App > Direct Distribution*,
   which also notarizes.)
4. Notarize and staple:

   ```sh
   cd build/export
   ditto -c -k --keepParent 'Hidden Bar Plus.app' HiddenBarPlus-1.0.0.zip
   xcrun notarytool submit HiddenBarPlus-1.0.0.zip --keychain-profile notary --wait
   xcrun stapler staple 'Hidden Bar Plus.app'
   rm HiddenBarPlus-1.0.0.zip
   ditto -c -k --keepParent 'Hidden Bar Plus.app' HiddenBarPlus-1.0.0.zip   # stapled copy
   ```

5. Confirm the shipped app is unsandboxed and hardened:

   ```sh
   codesign -d --entitlements - -vv 'Hidden Bar Plus.app' 2>&1 | grep -E 'app-sandbox|runtime'
   # must print the runtime flag and nothing about app-sandbox
   spctl -a -vv 'Hidden Bar Plus.app'   # "accepted ... source=Notarized Developer ID"
   ```

6. Appcast: keep a local folder with the zips of every release and run

   ```sh
   "$SPARKLE_BIN/generate_appcast" \
     --download-url-prefix https://github.com/SumOfOneInteger/HiddenBarPlus/releases/download/v1.0.0/ \
     path/to/release-zips
   ```

   It signs the new zip with your EdDSA key and writes `appcast.xml` next to
   the zips. Publish that `appcast.xml` at `SUFeedURL`.
7. Create the GitHub release `v1.0.0`, attach the stapled zip under exactly the
   name the appcast references, paste the CHANGELOG entry.
8. Homebrew: point the cask at the release and test it locally:

   ```sh
   scripts/update-cask.sh 1.0.0      # sets version + sha256 in Casks/hidden-bar-plus.rb
   brew install --cask ./Casks/hidden-bar-plus.rb
   brew uninstall --cask hidden-bar-plus
   ```

   Commit the updated cask. To publish it, create a repository named
   `homebrew-tap` under your account and copy the file to `Casks/` there; users
   then run `brew install --cask sumofoneinteger/tap/hidden-bar-plus`. Once the
   project meets homebrew-cask's acceptance criteria (an established repository
   with a notarized release and enough stars and forks; see their CONTRIBUTING),
   fork homebrew/homebrew-cask, add the same file under `Casks/h/`, run
   `brew audit --cask --new --online hidden-bar-plus` and `brew style --fix`,
   and open the PR there. Later releases only need `scripts/update-cask.sh`
   again.

## Tracking upstream

Hidden Bar Plus started from dwarvesf/hidden `develop` at v1.11.1.

```sh
git remote add upstream https://github.com/dwarvesf/hidden.git
git fetch upstream
git merge upstream/develop
```

Expect conflicts in the project file (renamed configurations, Sparkle) and in
branded strings; the Swift sources merge cleanly because they were left as
upstream wrote them.

## Issue triage map

The live clusters and their code areas are documented at the end of
[ARCHITECTURE.md](ARCHITECTURE.md#known-architectural-limits): notch, macOS 27
mechanism, and pointer-vs-open-menu limits. The inherited open items are in
[BACKLOG.md](BACKLOG.md).
