import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup SMC
        do {
            try SMCKit.shared.open()
        } catch {
            print("⚠️  SMC not available: \(error.localizedDescription)")
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Warm up CPU delta
        _ = SystemMonitor.shared.cpuUsage()

        // Start periodic refresh
        updateReadings()
        startTimer()

        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        CaffeineManager.shared.deactivate()
        HistoryStore.shared.save()
        SMCKit.shared.close()
    }

    // CRITICAL: prevent app from quitting when window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Re-opened from Dock click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // NSWindowDelegate: hide window instead of destroying
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    // MARK: - Timer Management

    func startTimer() {
        timer?.invalidate()
        let interval = SettingsManager.shared.refreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
    }

    func restartTimer() {
        startTimer()
    }

    /// Called when caffeine state changes to immediately refresh menu bar
    func refreshMenuBar() {
        updateStatusBarTitle()
        rebuildMenu()
    }

    // MARK: - Update Loop

    private func updateReadings() {
        MonitorState.shared.refresh()
        updateStatusBarTitle()
        rebuildMenu()
    }

    // MARK: - Status Bar Rendering

    /// Renders entire status bar content as a single template NSImage.
    /// This ensures proper dark/light mode adaptation — NSTextAttachment does NOT
    /// respect isTemplate, so we draw everything into one image instead.
    private func updateStatusBarTitle() {
        let state = MonitorState.shared
        let settings = SettingsManager.shared
        let style = settings.menuBarStyle
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let iconSize: CGFloat = 14
        let spacing: CGFloat = 3
        let sectionSpacing: CGFloat = 8

        // Build parts: each part is (icon?, text?)
        // Text uses fixed-width format to prevent shifting
        var parts: [(icon: MenuBarIcon?, text: String?)] = []

        if settings.showFanInMenuBar, let fan = state.fanSpeeds.first {
            // 4 chars: "1234" or " 800"
            parts.append((icon: .fan, text: String(format: "%4.0f", fan.rpm)))
        }
        if settings.showCPUTempInMenuBar && state.cpuTemp > 0 {
            // 3 chars + °: " 69°" or "100°"
            parts.append((icon: .thermometer, text: String(format: "%3.0f°", state.cpuTemp)))
        }
        if settings.showCPUInMenuBar {
            // 3 chars + %: "  5%" or "100%"
            parts.append((icon: .cpu, text: String(format: "%3.0f%%", state.cpuPercent)))
        }
        if settings.showRAMInMenuBar {
            // 3 chars + %: " 42%" or "100%"
            parts.append((icon: .memory, text: String(format: "%3.0f%%", state.memPercent)))
        }
        if settings.showCaffeineInMenuBar && CaffeineManager.shared.isActive {
            parts.append((icon: .caffeine, text: nil))
        }

        guard !parts.isEmpty else {
            let fallback = MenuBarIcon.cpu.image
            fallback.size = NSSize(width: iconSize, height: iconSize)
            statusItem.button?.image = fallback
            statusItem.button?.title = ""
            statusItem.length = NSStatusItem.variableLength
            return
        }

        // Calculate total width
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var totalWidth: CGFloat = 0

        for (index, part) in parts.enumerated() {
            if index > 0 { totalWidth += sectionSpacing }

            let showIcon = (style == .icon || style == .both) && part.icon != nil
            let showText = (style == .text || style == .both) && part.text != nil

            if showIcon { totalWidth += iconSize }
            if showIcon && showText { totalWidth += spacing }
            if showText, let text = part.text {
                totalWidth += (text as NSString).size(withAttributes: attrs).width
            }
            // icon-only with no text and no icon (caffeine with text style)
            if !showIcon && !showText && part.icon != nil {
                totalWidth += iconSize // always show icon for caffeine
            }
        }

        let height: CGFloat = 18
        let imgSize = NSSize(width: ceil(totalWidth), height: height)

        let img = NSImage(size: imgSize, flipped: false) { rect in
            var x: CGFloat = 0

            for (index, part) in parts.enumerated() {
                if index > 0 { x += sectionSpacing }

                let showIcon = (style == .icon || style == .both) && part.icon != nil
                let showText = (style == .text || style == .both) && part.text != nil
                // Special: caffeine always shows as icon
                let forceIcon = !showIcon && !showText && part.icon != nil

                if showIcon || forceIcon {
                    let iconImg = part.icon!.image
                    let iconRect = NSRect(x: x, y: (height - iconSize) / 2, width: iconSize, height: iconSize)
                    iconImg.draw(in: iconRect)
                    x += iconSize
                    if showText { x += spacing }
                }
                if showText, let text = part.text {
                    let textSize = (text as NSString).size(withAttributes: attrs)
                    let textY = (height - textSize.height) / 2
                    (text as NSString).draw(at: NSPoint(x: x, y: textY), withAttributes: attrs)
                    x += textSize.width
                }
            }
            return true
        }

        img.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = NSAttributedString()
        statusItem.length = NSStatusItem.variableLength
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        let state = MonitorState.shared

        // Header
        let headerItem = NSMenuItem(title: "Rancage", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // CPU
        let cpuItem = NSMenuItem(title: String(format: "CPU: %.1f%%", state.cpuPercent), action: nil, keyEquivalent: "")
        cpuItem.image = MenuBarIcon.cpu.image
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)

        if state.cpuTemp > 0 {
            let tempItem = NSMenuItem(title: String(format: "Temp: %.1f°C", state.cpuTemp), action: nil, keyEquivalent: "")
            tempItem.image = MenuBarIcon.thermometer.image
            tempItem.isEnabled = false
            menu.addItem(tempItem)
        }
        menu.addItem(NSMenuItem.separator())

        // Memory
        let memItem = NSMenuItem(title: String(format: "RAM: %.1f%% (%.1f / %.1f GB)", state.memPercent, state.memUsedGB, state.memTotalGB), action: nil, keyEquivalent: "")
        memItem.image = MenuBarIcon.memory.image
        memItem.isEnabled = false
        menu.addItem(memItem)
        menu.addItem(NSMenuItem.separator())

        // Fans
        if !state.fanSpeeds.isEmpty {
            for fan in state.fanSpeeds {
                let label = state.fanSpeeds.count == 1 ? "Fan" : "Fan \(fan.index)"
                let fanItem = NSMenuItem(title: String(format: "%@: %.0f RPM", label, fan.rpm), action: nil, keyEquivalent: "")
                fanItem.image = MenuBarIcon.fan.image
                fanItem.isEnabled = false
                menu.addItem(fanItem)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // Caffeine
        let caffeineTitle = CaffeineManager.shared.isActive ? "Stay Awake: ON" : "Stay Awake: OFF"
        let caffeineItem = NSMenuItem(title: caffeineTitle, action: #selector(toggleCaffeine), keyEquivalent: "c")
        caffeineItem.image = CaffeineManager.shared.isActive ? MenuBarIcon.caffeine.image : MenuBarIcon.caffeineOff.image
        caffeineItem.target = self
        menu.addItem(caffeineItem)

        menu.addItem(NSMenuItem.separator())

        // Open window
        let dashItem = NSMenuItem(title: "Open Rancage…", action: #selector(showMainWindow), keyEquivalent: "o")
        dashItem.target = self
        menu.addItem(dashItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Rancage", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleCaffeine() {
        _ = CaffeineManager.shared.toggle()
        updateStatusBarTitle()
        rebuildMenu()
    }

    @objc func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MainWindowView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rancage"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("RancageMainWindow")
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
