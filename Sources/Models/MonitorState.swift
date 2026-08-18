import Foundation
import Combine
import UserNotifications

/// Central observable state for all monitor readings.
/// SMC/system polling runs on a background queue to avoid blocking the main thread.
final class MonitorState: ObservableObject {
    static let shared = MonitorState()

    @Published var cpuPercent: Double = 0
    @Published var cpuTemp: Double = 0
    @Published var gpuTemp: Double = 0
    @Published var memPercent: Double = 0
    @Published var memUsedGB: Double = 0
    @Published var memTotalGB: Double = 0
    @Published var fanSpeeds: [(index: Int, rpm: Double, min: Double, max: Double)] = []
    @Published var smcAvailable: Bool = false

    private let pollQueue = DispatchQueue(label: "com.rancage.monitor", qos: .userInitiated)
    private var lastAlertTime: Date = .distantPast

    /// Guard against overlapping refreshes
    private var isRefreshing = false

    /// Whether notification authorization has been requested
    private var notificationAuthorized: Bool?

    private init() {
        smcAvailable = SMCKit.shared.isOpen
        requestNotificationAuth()
    }

    /// Request notification authorization once at init.
    /// Guarded: UNUserNotificationCenter crashes when the app lacks a bundle identifier
    /// (e.g. running via `swift run` without a .app wrapper).
    private func requestNotificationAuth() {
        guard Bundle.main.bundleIdentifier != nil else {
            notificationAuthorized = false
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationAuthorized = granted
            }
        }
    }

    /// Refresh all readings. Polling happens on background queue,
    /// results are dispatched back to main thread for UI updates.
    /// Prevents overlapping refreshes.
    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        pollQueue.async { [weak self] in
            guard let self = self else { return }

            let cpu = SystemMonitor.shared.cpuUsage()
            let mem = SystemMonitor.shared.memoryUsage()

            let isOpen = SMCKit.shared.isOpen
            var cpuT: Double = 0
            var gpuT: Double = 0
            var fans: [(index: Int, rpm: Double, min: Double, max: Double)] = []

            if isOpen {
                // CPU temperature
                let cpuTempKeys = ["TC0P", "TC0H", "TC0D", "TC0E", "TC0F", "TCXC"]
                for key in cpuTempKeys {
                    if let t = try? SMCKit.shared.readTemperature(key), t > 0 {
                        cpuT = t
                        break
                    }
                }

                // GPU temperature
                let gpuTempKeys = ["TG0P", "TG0D", "TG0H", "TGDD"]
                for key in gpuTempKeys {
                    if let t = try? SMCKit.shared.readTemperature(key), t > 0 {
                        gpuT = t
                        break
                    }
                }

                // Fans with min/max
                if let count = try? SMCKit.shared.readFanCount(), count > 0 {
                    fans = (0..<count).compactMap { i in
                        guard let rpm = try? SMCKit.shared.readFanSpeed(i) else { return nil }
                        let minRPM = (try? SMCKit.shared.readFanMin(i)) ?? 0
                        let maxRPM = (try? SMCKit.shared.readFanMax(i)) ?? 0
                        return (index: i, rpm: rpm, min: minRPM, max: maxRPM)
                    }
                }
            }

            let fanRPM = fans.first?.rpm ?? 0

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isRefreshing = false

                self.cpuPercent = cpu
                self.memPercent = mem.percentage
                self.memUsedGB = mem.usedGB
                self.memTotalGB = mem.totalGB
                self.smcAvailable = isOpen
                self.cpuTemp = cpuT
                self.gpuTemp = gpuT
                self.fanSpeeds = fans

                HistoryStore.shared.record(cpu: cpu, cpuTemp: cpuT, ram: mem.percentage, fanRPM: fanRPM)

                // Check temperature alerts
                self.checkAlerts(cpuTemp: cpuT, gpuTemp: gpuT, ramPercent: mem.percentage)
            }
        }
    }

    // MARK: - Alerts

    private func checkAlerts(cpuTemp: Double, gpuTemp: Double, ramPercent: Double) {
        let settings = SettingsManager.shared
        guard settings.alertsEnabled else { return }
        guard notificationAuthorized == true else { return }

        // Throttle: max 1 alert per 60 seconds
        guard Date().timeIntervalSince(lastAlertTime) > 60 else { return }

        let threshold = settings.tempAlertThreshold
        var alerts: [String] = []

        if cpuTemp >= threshold && cpuTemp > 0 {
            alerts.append(String(format: "CPU: %.0f°C", cpuTemp))
        }
        if gpuTemp >= threshold && gpuTemp > 0 {
            alerts.append(String(format: "GPU: %.0f°C", gpuTemp))
        }
        if ramPercent >= settings.ramAlertThreshold {
            alerts.append(String(format: "RAM: %.0f%%", ramPercent))
        }

        guard !alerts.isEmpty else { return }

        lastAlertTime = Date()
        sendNotification(
            title: "⚠️ Rancage Alert",
            body: alerts.joined(separator: ", ") + " exceeded threshold"
        )
    }

    private func sendNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "rancage-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
