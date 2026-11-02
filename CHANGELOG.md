# Changelog

## Unreleased: Hidden Bar Plus 1.0.0

Hidden Bar Plus starts from Hidden Bar v1.11.1 (dwarvesf/hidden, 2026-09-18). The
entries below this one are upstream's history and keep upstream's issue numbers.

### Changed
- Rebranded as Hidden Bar Plus. New bundle identifier `com.sumofoneinteger.hiddenbarplus`,
  so the app installs next to Hidden Bar and starts with fresh preferences.
- One build only. The former `Debug-Direct` / `Release-Direct` configurations are
  now `Debug` / `Release`; the App Store scheme, its sandboxed configurations and
  the sandbox entitlement are gone. Native hiding on macOS 27 is always compiled in.
- No development team is set in the project; pick yours in Xcode or pass
  `DEVELOPMENT_TEAM` on the command line.
- Version numbering restarts at 1.0.0 (build 1).
- About screen links point at this repository and credit Hidden Bar.

### Added
- Sparkle 2 auto-updates: *Check for Updates…* in the context menu and the
  standard automatic-check prompt. The appcast URL in `Info.plist` is a placeholder
  until update hosting exists, and `SUPublicEDKey` must be added before the first release.
- Placeholder app icon, regenerable with `swift scripts/make-placeholder-icon.swift .`.

## v1.11.1 (2026-09-18)

### Fixed
- macOS 27: the Preferences window showed a "Custom View" placeholder instead of the General/About tabs, and the label overlapped the window once clicked (#406).

## v1.11 (2026-09-18)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Added
- Opt-in hover-to-expand: set `defaults write com.dwarvesv.minimalbar hoverToExpand -bool true` to expand the bar when the pointer dwells in the menu bar.
- Right-clicking the expand/collapse arrow now opens the same context menu as the separator, so Preferences is reachable from the control you already click.

### Fixed
- macOS 27 (direct download build): hiding works again (#360) using macOS 27's native menu-bar visibility instead of widening the separator, which macOS 27 ejects from the bar. The arrow is the boundary: icons ⌘-dragged to its left hide when collapsed. Needs the Accessibility permission, and Hidden Bar must run from /Applications. Hiding is per app, and macOS's own items always stay visible. The App Store build is unchanged for now.
- Enabling the always-hidden section at runtime no longer creates an invisible (0pt) separator.
- Multi-display: the collapse width is now sized for the widest attached screen, so icons no longer leak on wider external monitors; the width re-applies on display hot-plug.
- Auto-collapse no longer fires while you are interacting with the menu bar (the timer defers and re-arms while the pointer is in the bar).
- The Preferences window no longer closes when auto-collapse fires with "use full menu bar on expanding" enabled (#170, #66, #151).
- Status items that were dragged off the bar are restored at launch instead of leaving the app unreachable.
- Fixed constraint and observer leaks in the tutorial view rebuild.
- Tutorial strings and F-key shortcut labels now render correctly (no more private-use glyphs).

### Changed
- Start-at-login now uses `SMAppService` (macOS 13+); the legacy launcher helper was removed and any leftover login item is deauthorized automatically on first launch.
- Pinned the HotKey dependency to an exact version and removed an unused file-access entitlement and dead code (no behavior change).

### Known / in progress
- macOS 27, App Store build: hiding still does not work (#360). Native hiding needs Accessibility reads that the App Sandbox blocks; an App Store approach is tracked separately.
- New menu-bar icons can appear in the hidden zone because macOS inserts them at the far left; ⌘-drag them to the right of the separator (see the manual). A built-in pin is part of the planned redesign.
