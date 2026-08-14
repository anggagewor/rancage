import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var mainWindow: NSWindow?

    private let menuBarRenderer = MenuBarRenderer()
    private lazy var menuBuilder = MenuBuilder(target: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup global menu bar
        setupMainMenu()

        // Setup SMC
        do {
            try SMCKit.shared.open()
        } catch {
            print("⚠️  SMC not available: \(error.localizedDescription)")
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Use a lazy menu that rebuilds on open via NSMenuDelegate
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Warm up CPU delta
        _ = SystemMonitor.shared.cpuUsage()

        // Restore caffeine state (after everything is set up)
        CaffeineManager.shared.restoreState()

        // Start periodic refresh
        updateReadings()
        startTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        CaffeineManager.shared.releaseWithoutPersist()
        HistoryStore.shared.save()
        SettingsManager.shared.save()
        SMCKit.shared.close()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    // MARK: - NSMenuDelegate

    /// Build menu content on-demand when user clicks the status item.
    /// This avoids rebuilding the entire menu every refresh tick.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let built = menuBuilder.build()
        // Transfer items from built menu to our persistent menu
        while let item = built.item(at: 0) {
            built.removeItem(item)
            menu.addItem(item)
        }
    }

    // MARK: - Timer

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

    func refreshMenuBar() {
        updateStatusBar()
    }

    // MARK: - Update Loop

    private func updateReadings() {
        MonitorState.shared.refresh()
        // MonitorState dispatches to main when done; update status bar icon on next run loop
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBar()
        }
    }

    private func updateStatusBar() {
        let parts = menuBarRenderer.buildParts()
        let style = SettingsManager.shared.menuBarStyle

        if let img = menuBarRenderer.render(parts: parts, style: style) {
            statusItem.button?.image = img
            statusItem.button?.title = ""
            statusItem.button?.attributedTitle = NSAttributedString()
        } else {
            // Fallback
            let fallback = MenuBarIcon.cpu.image
            fallback.size = NSSize(width: 14, height: 14)
            statusItem.button?.image = fallback
            statusItem.button?.title = ""
        }
        statusItem.length = NSStatusItem.variableLength
    }

    // MARK: - Actions (exposed for MenuBuilder selectors)

    @objc func toggleCaffeineAction() {
        _ = CaffeineManager.shared.toggle()
        refreshMenuBar()
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

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Global Menu Bar

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Rancage", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(showMainWindow), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        let hideItem = NSMenuItem(title: "Hide Rancage", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Rancage", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenu = NSMenu(title: "Help")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }
}
