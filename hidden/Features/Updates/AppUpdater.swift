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

    /// Starts the updater. Skipped when the app runs as a unit-test host, and
    /// when Sparkle is not configured yet (no `SUPublicEDKey` in Info.plist):
    /// in both cases Sparkle would otherwise report a configuration error on
    /// every launch of a development build. "Check for Updates..." stays
    /// disabled until the updater has started.
    func start() {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestSessionIdentifier"] != nil {
            return
        }
        guard let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !publicKey.isEmpty else {
            NSLog("AppUpdater: SUPublicEDKey is missing from Info.plist; updates stay disabled until it is set (see docs/RUNBOOK.md).")
            return
        }
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
