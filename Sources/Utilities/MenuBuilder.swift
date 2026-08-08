import AppKit

/// Builds the NSMenu for the status bar dropdown.
/// Extracted from AppDelegate to reduce God Object complexity.
final class MenuBuilder {

    weak var target: AnyObject?

    init(target: AnyObject?) {
        self.target = target
    }

    func build() -> NSMenu {
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
        let caffeineItem = NSMenuItem(title: caffeineTitle, action: #selector(AppDelegate.toggleCaffeineAction), keyEquivalent: "c")
        caffeineItem.image = CaffeineManager.shared.isActive ? MenuBarIcon.caffeine.image : MenuBarIcon.caffeineOff.image
        caffeineItem.target = target
        menu.addItem(caffeineItem)

        menu.addItem(NSMenuItem.separator())

        // Open window
        let dashItem = NSMenuItem(title: "Open Rancage…", action: #selector(AppDelegate.showMainWindow), keyEquivalent: "o")
        dashItem.target = target
        menu.addItem(dashItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Rancage", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
