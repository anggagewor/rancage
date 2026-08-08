import AppKit
import SwiftUI

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy based on settings
let settings = SettingsManager.shared
if settings.showDockIcon {
    app.setActivationPolicy(.regular)
} else {
    app.setActivationPolicy(.accessory)
}

// Listen for refresh interval changes
NotificationCenter.default.addObserver(
    forName: .refreshIntervalChanged,
    object: nil,
    queue: .main
) { _ in
    delegate.restartTimer()
}

// Listen for caffeine state changes → immediately update menu bar
NotificationCenter.default.addObserver(
    forName: .caffeineStateChanged,
    object: nil,
    queue: .main
) { _ in
    delegate.refreshMenuBar()
}

app.run()
