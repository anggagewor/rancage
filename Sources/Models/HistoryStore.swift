import Foundation

/// Stores historical data points for graphs.
/// Persisted to ~/.cache/rancage/history.json on quit, loaded on launch.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private let cacheDir: URL
    private let cacheFile: URL
    private let maxPoints = 300 // ~5 min at 1s interval

    @Published var cpuHistory: [DataPoint] = []
    @Published var cpuTempHistory: [DataPoint] = []
    @Published var ramHistory: [DataPoint] = []
    @Published var fanHistory: [DataPoint] = []

    struct DataPoint: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let value: Double

        init(value: Double) {
            self.id = UUID()
            self.timestamp = Date()
            self.value = value
        }
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = home.appendingPathComponent(".cache/rancage")
        cacheFile = cacheDir.appendingPathComponent("history.json")
        load()
    }

    func record(cpu: Double, cpuTemp: Double, ram: Double, fanRPM: Double) {
        cpuHistory.append(DataPoint(value: cpu))
        cpuTempHistory.append(DataPoint(value: cpuTemp))
        ramHistory.append(DataPoint(value: ram))
        fanHistory.append(DataPoint(value: fanRPM))

        // Trim to max size
        if cpuHistory.count > maxPoints { cpuHistory.removeFirst(cpuHistory.count - maxPoints) }
        if cpuTempHistory.count > maxPoints { cpuTempHistory.removeFirst(cpuTempHistory.count - maxPoints) }
        if ramHistory.count > maxPoints { ramHistory.removeFirst(ramHistory.count - maxPoints) }
        if fanHistory.count > maxPoints { fanHistory.removeFirst(fanHistory.count - maxPoints) }
    }

    // MARK: - Persistence

    private struct CacheData: Codable {
        var cpuHistory: [DataPoint]
        var cpuTempHistory: [DataPoint]
        var ramHistory: [DataPoint]
        var fanHistory: [DataPoint]
    }

    func save() {
        let cacheData = CacheData(
            cpuHistory: cpuHistory,
            cpuTempHistory: cpuTempHistory,
            ramHistory: ramHistory,
            fanHistory: fanHistory
        )
        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cacheData)
            try data.write(to: cacheFile, options: .atomic)
        } catch {
            print("⚠️  Failed to save history: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: cacheFile.path) else { return }
        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode(CacheData.self, from: data)

            // Only keep recent data (last 5 minutes)
            let cutoff = Date().addingTimeInterval(-300)
            cpuHistory = cached.cpuHistory.filter { $0.timestamp > cutoff }
            cpuTempHistory = cached.cpuTempHistory.filter { $0.timestamp > cutoff }
            ramHistory = cached.ramHistory.filter { $0.timestamp > cutoff }
            fanHistory = cached.fanHistory.filter { $0.timestamp > cutoff }
        } catch {
            print("⚠️  Failed to load history cache: \(error)")
        }
    }
}
