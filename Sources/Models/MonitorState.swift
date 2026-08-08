import Foundation
import Combine

/// Central observable state for all monitor readings
final class MonitorState: ObservableObject {
    static let shared = MonitorState()

    @Published var cpuPercent: Double = 0
    @Published var cpuTemp: Double = 0
    @Published var memPercent: Double = 0
    @Published var memUsedGB: Double = 0
    @Published var memTotalGB: Double = 0
    @Published var fanSpeeds: [(index: Int, rpm: Double)] = []
    @Published var smcAvailable: Bool = false

    private init() {
        smcAvailable = SMCKit.shared.isOpen
    }

    func refresh() {
        cpuPercent = SystemMonitor.shared.cpuUsage()

        let mem = SystemMonitor.shared.memoryUsage()
        memPercent = mem.percentage
        memUsedGB = mem.usedGB
        memTotalGB = mem.totalGB

        smcAvailable = SMCKit.shared.isOpen

        if smcAvailable {
            cpuTemp = 0
            let tempKeys = ["TC0P", "TC0H", "TC0D", "TC0E", "TC0F", "TCXC"]
            for key in tempKeys {
                if let temp = try? SMCKit.shared.readTemperature(key), temp > 0 {
                    cpuTemp = temp
                    break
                }
            }

            if let count = try? SMCKit.shared.readFanCount(), count > 0 {
                fanSpeeds = (0..<count).compactMap { i in
                    guard let rpm = try? SMCKit.shared.readFanSpeed(i) else { return nil }
                    return (index: i, rpm: rpm)
                }
            }
        }

        // Record to history
        let fanRPM = fanSpeeds.first?.rpm ?? 0
        HistoryStore.shared.record(cpu: cpuPercent, cpuTemp: cpuTemp, ram: memPercent, fanRPM: fanRPM)
    }
}
