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

        // Caffeine toggle
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
