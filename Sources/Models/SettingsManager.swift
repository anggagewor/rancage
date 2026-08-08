import Foundation
import AppKit

/// User settings stored in ~/.config/rancage/settings.json
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let configDir: URL
    private let configFile: URL

    // Menu bar display
    @Published var showCPUInMenuBar: Bool = true { didSet { save() } }
    @Published var showCPUTempInMenuBar: Bool = true { didSet { save() } }
    @Published var showRAMInMenuBar: Bool = true { didSet { save() } }
    @Published var showFanInMenuBar: Bool = true { didSet { save() } }
    @Published var showCaffeineInMenuBar: Bool = true { didSet { save() } }

    // Menu bar style: "icon", "text", "both"
    @Published var menuBarStyle: MenuBarStyle = .both { didSet { save() } }

    // Appearance
    @Published var showDockIcon: Bool = false {
        didSet {
            save()
            applyDockIconPolicy()
        }
    }

    // Refresh interval in seconds
    @Published var refreshInterval: Double = 1.0 { didSet { save() } }

    enum MenuBarStyle: String, Codable, CaseIterable {
        case icon = "icon"
        case text = "text"
        case both = "both"

        var label: String {
            switch self {
            case .icon: return "Icon Only"
            case .text: return "Text Only"
            case .both: return "Both"
            }
        }
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/rancage")
        configFile = configDir.appendingPathComponent("settings.json")
        load()
    }

    // MARK: - Persistence

    private struct SettingsData: Codable {
        var showCPUInMenuBar: Bool?
        var showCPUTempInMenuBar: Bool?
        var showRAMInMenuBar: Bool?
        var showFanInMenuBar: Bool?
        var showCaffeineInMenuBar: Bool?
        var menuBarStyle: MenuBarStyle?
        var showDockIcon: Bool?
        var refreshInterval: Double?
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: configFile.path) else { return }
        do {
            let data = try Data(contentsOf: configFile)
            let decoded = try JSONDecoder().decode(SettingsData.self, from: data)
            if let v = decoded.showCPUInMenuBar { showCPUInMenuBar = v }
            if let v = decoded.showCPUTempInMenuBar { showCPUTempInMenuBar = v }
            if let v = decoded.showRAMInMenuBar { showRAMInMenuBar = v }
            if let v = decoded.showFanInMenuBar { showFanInMenuBar = v }
            if let v = decoded.showCaffeineInMenuBar { showCaffeineInMenuBar = v }
            if let v = decoded.menuBarStyle { menuBarStyle = v }
            if let v = decoded.showDockIcon { showDockIcon = v }
            if let v = decoded.refreshInterval { refreshInterval = v }
        } catch {
            print("⚠️  Failed to load settings: \(error)")
        }
    }

    func save() {
        let settingsData = SettingsData(
            showCPUInMenuBar: showCPUInMenuBar,
            showCPUTempInMenuBar: showCPUTempInMenuBar,
            showRAMInMenuBar: showRAMInMenuBar,
            showFanInMenuBar: showFanInMenuBar,
            showCaffeineInMenuBar: showCaffeineInMenuBar,
            menuBarStyle: menuBarStyle,
            showDockIcon: showDockIcon,
            refreshInterval: refreshInterval
        )
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settingsData)
            try data.write(to: configFile, options: .atomic)
        } catch {
            print("⚠️  Failed to save settings: \(error)")
        }
    }

    private func applyDockIconPolicy() {
        if showDockIcon {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
