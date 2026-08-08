import Foundation
import Combine

/// Central observable state for all monitor readings.
/// SMC/system polling runs on a background queue to avoid blocking the main thread.
final class MonitorState: ObservableObject {
    static let shared = MonitorState()

    @Published var cpuPercent: Double = 0
    @Published var cpuTemp: Double = 0
    @Published var memPercent: Double = 0
    @Published var memUsedGB: Double = 0
    @Published var memTotalGB: Double = 0
    @Published var fanSpeeds: [(index: Int, rpm: Double)] = []
    @Published var smcAvailable: Bool = false

    private let pollQueue = DispatchQueue(label: "com.rancage.monitor", qos: .userInitiated)

    private init() {
        smcAvailable = SMCKit.shared.isOpen
    }

    /// Refresh all readings. Polling happens on background queue,
    /// results are dispatched back to main thread for UI updates.
    func refresh() {
        pollQueue.async { [self] in
            let cpu = SystemMonitor.shared.cpuUsage()
            let mem = SystemMonitor.shared.memoryUsage()

            let isOpen = SMCKit.shared.isOpen
            var temp: Double = 0
            var fans: [(index: Int, rpm: Double)] = []

            if isOpen {
                let tempKeys = ["TC0P", "TC0H", "TC0D", "TC0E", "TC0F", "TCXC"]
                for key in tempKeys {
                    if let t = try? SMCKit.shared.readTemperature(key), t > 0 {
                        temp = t
                        break
                    }
                }

                if let count = try? SMCKit.shared.readFanCount(), count > 0 {
                    fans = (0..<count).compactMap { i in
                        guard let rpm = try? SMCKit.shared.readFanSpeed(i) else { return nil }
                        return (index: i, rpm: rpm)
                    }
                }
            }

            let fanRPM = fans.first?.rpm ?? 0

            DispatchQueue.main.async { [self] in
                self.cpuPercent = cpu
                self.memPercent = mem.percentage
                self.memUsedGB = mem.usedGB
                self.memTotalGB = mem.totalGB
                self.smcAvailable = isOpen
                self.cpuTemp = temp
                self.fanSpeeds = fans

                HistoryStore.shared.record(cpu: cpu, cpuTemp: temp, ram: mem.percentage, fanRPM: fanRPM)
            }
        }
    }
}
