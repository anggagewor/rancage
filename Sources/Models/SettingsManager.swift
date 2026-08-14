import Foundation
import AppKit

/// User settings stored in ~/.config/rancage/settings.json
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let configDir: URL
    private let configFile: URL
    private var isLoading = false

    /// Background queue for debounced saves
    private let saveQueue = DispatchQueue(label: "com.rancage.settings.save", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    // Menu bar display
    @Published var showCPUInMenuBar: Bool = true { didSet { scheduleSave() } }
    @Published var showCPUTempInMenuBar: Bool = true { didSet { scheduleSave() } }
    @Published var showRAMInMenuBar: Bool = true { didSet { scheduleSave() } }
    @Published var showFanInMenuBar: Bool = true { didSet { scheduleSave() } }
    @Published var showCaffeineInMenuBar: Bool = true { didSet { scheduleSave() } }

    // Menu bar style: "icon", "text", "both"
    @Published var menuBarStyle: MenuBarStyle = .both { didSet { scheduleSave() } }

    // Appearance
    @Published var showDockIcon: Bool = false {
        didSet {
            scheduleSave()
            applyDockIconPolicy()
        }
    }

    // Refresh interval in seconds
    @Published var refreshInterval: Double = 1.0 {
        didSet {
            // Clamp to sane range
            let clamped = max(0.5, min(30.0, refreshInterval))
            if refreshInterval != clamped {
                refreshInterval = clamped
                return
            }
            scheduleSave()
        }
    }

    // Stay Awake (Caffeine) — persisted so it restores on relaunch
    @Published var stayAwake: Bool = false { didSet { scheduleSave() } }
    @Published var caffeineMode: CaffeineMode = .preventSleep {
        didSet {
            scheduleSave()
            if !isLoading {
                CaffeineManager.shared.reapplyMode()
            }
        }
    }

    // Alerts
    @Published var alertsEnabled: Bool = true { didSet { scheduleSave() } }
    @Published var tempAlertThreshold: Double = 90 { didSet { scheduleSave() } }
    @Published var ramAlertThreshold: Double = 90 { didSet { scheduleSave() } }

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
        var stayAwake: Bool?
        var caffeineMode: CaffeineMode?
        var alertsEnabled: Bool?
        var tempAlertThreshold: Double?
        var ramAlertThreshold: Double?
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: configFile.path) else { return }
        isLoading = true
        defer { isLoading = false }
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
            if let v = decoded.refreshInterval { refreshInterval = max(0.5, min(30.0, v)) }
            if let v = decoded.stayAwake { stayAwake = v }
            if let v = decoded.caffeineMode { caffeineMode = v }
            if let v = decoded.alertsEnabled { alertsEnabled = v }
            if let v = decoded.tempAlertThreshold { tempAlertThreshold = v }
            if let v = decoded.ramAlertThreshold { ramAlertThreshold = v }
        } catch {
            print("⚠️  Failed to load settings: \(error)")
        }
    }

    /// Debounced save: coalesces rapid changes into a single disk write.
    private func scheduleSave() {
        guard !isLoading else { return }
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// Immediate save — called on app quit to flush pending changes.
    func save() {
        saveWorkItem?.cancel()
        performSave()
    }

    private func performSave() {
        let settingsData = SettingsData(
            showCPUInMenuBar: showCPUInMenuBar,
            showCPUTempInMenuBar: showCPUTempInMenuBar,
            showRAMInMenuBar: showRAMInMenuBar,
            showFanInMenuBar: showFanInMenuBar,
            showCaffeineInMenuBar: showCaffeineInMenuBar,
            menuBarStyle: menuBarStyle,
            showDockIcon: showDockIcon,
            refreshInterval: refreshInterval,
            stayAwake: stayAwake,
            caffeineMode: caffeineMode,
            alertsEnabled: alertsEnabled,
            tempAlertThreshold: tempAlertThreshold,
            ramAlertThreshold: ramAlertThreshold
        )
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settingsData)
            try data.write(to: configFile, options: .atomic)

            // Restrict file permissions to owner only (0600)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: configFile.path
            )
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
