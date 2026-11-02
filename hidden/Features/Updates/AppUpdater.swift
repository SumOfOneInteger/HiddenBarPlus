//
//  AppUpdater.swift
//  Hidden Bar Plus
//
//  Copyright © 2026 SumOfOneInteger. MIT License.
//

import AppKit
import Sparkle

/// Owns the Sparkle updater for the lifetime of the app.
///
/// Sparkle is configured entirely through Info.plist: `SUFeedURL` points at the
/// appcast and `SUPublicEDKey` holds the EdDSA public key that signed updates
/// are verified against. Nothing here is release-specific.
final class AppUpdater: NSObject {
    static let shared = AppUpdater()

    private let controller: SPUStandardUpdaterController

    private override init() {
        // Not started from the initializer so that `start()` can be called at
        // a defined point in launch (after the single-instance check). If the
        // configuration is incomplete, e.g. a dev build without a public key,
        // Sparkle logs the reason and `canCheckForUpdates` stays false; the app
        // itself is unaffected.
        controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        super.init()
    }

    func start() {
        controller.startUpdater()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }
}

extension AppUpdater: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates(_:)) {
            return controller.updater.canCheckForUpdates
        }
        return true
    }
}
