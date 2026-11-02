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

Releases are built by the **Release** GitHub Actions workflow
(`.github/workflows/release.yml`) on a macOS runner: universal archive,
Developer ID signing, notarization, stapling, Sparkle appcast, GitHub release,
appcast publish to GitHub Pages, Homebrew cask. Until the one-time setup below
is complete the workflow stops at its first step with the list of missing
secrets.

### One-time setup

1. **Apple Developer Program** membership. In Xcode > Settings > Accounts >
   Manage Certificates create a *Developer ID Application* certificate. Export
   it from Keychain Access as a `.p12` with a password, then
   `base64 -i DeveloperID.p12 | pbcopy`.
2. **App-specific password** for notarization: appleid.apple.com > Sign-In and
   Security > App-Specific Passwords.
3. **Sparkle keys.** The tools ship inside the resolved package:

   ```sh
   SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -type d \
     -path '*artifacts/sparkle/Sparkle/bin' | head -1)
   "$SPARKLE_BIN/generate_keys"                          # prints the public key
   "$SPARKLE_BIN/generate_keys" -x sparkle_private.key   # exports the private key
   ```

   Put the public key in `hidden/Info.plist` as `SUPublicEDKey` (replace the
   comment there) and commit. Keep `sparkle_private.key` somewhere safe and out
   of the repo: losing it strands every installed copy, because they refuse
   updates signed with a different key.
4. **Repository secrets** (Settings > Secrets and variables > Actions):

   | Secret | Value |
   |---|---|
   | `APPLE_TEAM_ID` | 10-character team id |
   | `DEVELOPER_ID_APPLICATION_P12_BASE64` | the base64 from step 1 |
   | `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | the `.p12` password |
   | `APPLE_ID` | your Apple ID email |
   | `APPLE_APP_SPECIFIC_PASSWORD` | from step 2 |
   | `SPARKLE_PRIVATE_KEY` | contents of `sparkle_private.key` |
   | `HOMEBREW_TAP_TOKEN` (optional) | fine-grained PAT with *Contents: write* on `homebrew-tap` |

5. **GitHub Pages.** The `gh-pages` branch holds `appcast.xml` (an empty feed
   until the first release) and an index page. In Settings > Pages set Source to
   *Deploy from a branch*, branch `gh-pages`, folder `/ (root)`. A minute later
   `SUFeedURL` (`https://sumofoneinteger.github.io/HiddenBarPlus/appcast.xml`)
   must return the feed. That URL must never move once users have the app.
6. **Homebrew tap.** Create an empty repository named `homebrew-tap` under your
   account. `homebrew-tap/README.md` in this repo is its README; the release
   workflow (with `HOMEBREW_TAP_TOKEN`) or `scripts/publish-tap.sh` fills it.
7. **Dry run.** Actions > Release > Run workflow with *publish* off. It signs,
   notarizes and builds the appcast without publishing anything and uploads the
   results as a workflow artifact. Fix whatever it reports before tagging.

### Each release

1. Bump `MARKETING_VERSION` (what users see, e.g. 1.0.1) and
   `CURRENT_PROJECT_VERSION` (an integer that must increase every release;
   Sparkle compares it, and the workflow refuses a build number that is not
   newer than the published appcast) in the project file, both configurations.
2. Give the CHANGELOG entry a heading that contains the version, e.g.
   `## 1.0.1 (2026-12-01)`. The workflow turns that section into the release
   notes and refuses to run without it.
3. Commit, tag, push:

   ```sh
   git tag v1.0.1 && git push origin main v1.0.1
   ```

   The workflow checks that the tag matches `MARKETING_VERSION`, publishes the
   GitHub release `v1.0.1` with `HiddenBarPlus-1.0.1.zip`, updates
   `appcast.xml` on `gh-pages`, commits the updated cask to `main` and, with
   `HOMEBREW_TAP_TOKEN`, to the tap. Installed copies see the update on their
   next check.
4. If the tap step was skipped: `git pull`, then `scripts/publish-tap.sh`.
5. homebrew-cask: once the project meets their acceptance criteria (an
   established repository with a notarized release and enough stars and forks;
   see their CONTRIBUTING), fork homebrew/homebrew-cask, add
   `Casks/hidden-bar-plus.rb` under `Casks/h/`, run
   `brew audit --cask --new --online hidden-bar-plus` and `brew style --fix`,
   and open the PR there.

### Manual release (fallback)

The workflow is a script of these steps; run them by hand if Actions is
unavailable. Fill `teamID` in `scripts/ExportOptions.plist` first, and store
notarization credentials once with
`xcrun notarytool store-credentials notary --apple-id you@example.com --team-id XXXXXXXXXX`.

```sh
xcodebuild -project 'Hidden Bar Plus.xcodeproj' -scheme 'Hidden Bar Plus' \
  -configuration Release -archivePath build/HiddenBarPlus.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/HiddenBarPlus.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/export
cd build/export
ditto -c -k --keepParent 'Hidden Bar Plus.app' HiddenBarPlus-1.0.0.zip
xcrun notarytool submit HiddenBarPlus-1.0.0.zip --keychain-profile notary --wait
xcrun stapler staple 'Hidden Bar Plus.app'
rm HiddenBarPlus-1.0.0.zip && ditto -c -k --keepParent 'Hidden Bar Plus.app' HiddenBarPlus-1.0.0.zip
codesign -d --entitlements - -vv 'Hidden Bar Plus.app' 2>&1 | grep -E 'app-sandbox|runtime'  # runtime yes, sandbox no
spctl -a -vv 'Hidden Bar Plus.app'                                                            # Notarized Developer ID
```

Then, in a folder holding that zip and the current `appcast.xml` from
`gh-pages`:

```sh
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix https://github.com/SumOfOneInteger/HiddenBarPlus/releases/download/v1.0.0/ \
  --link https://github.com/SumOfOneInteger/HiddenBarPlus/releases .
```

Create the GitHub release `v1.0.0` with the zip attached under exactly that
name, commit the new `appcast.xml` to `gh-pages`, then
`scripts/update-cask.sh 1.0.0 && scripts/publish-tap.sh`.

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
