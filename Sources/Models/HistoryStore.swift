import Foundation

/// Stores historical data points for graphs.
/// Persisted to ~/.cache/rancage/history.json periodically and on quit.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private let cacheDir: URL
    private let cacheFile: URL
    private let maxPoints = 300 // ~5 min at 1s interval

    /// Auto-save every 60 seconds to prevent data loss on crash
    private var saveCounter = 0
    private let saveInterval = 60

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

        // Trim using suffix for better performance than removeFirst
        if cpuHistory.count > maxPoints { cpuHistory = Array(cpuHistory.suffix(maxPoints)) }
        if cpuTempHistory.count > maxPoints { cpuTempHistory = Array(cpuTempHistory.suffix(maxPoints)) }
        if ramHistory.count > maxPoints { ramHistory = Array(ramHistory.suffix(maxPoints)) }
        if fanHistory.count > maxPoints { fanHistory = Array(fanHistory.suffix(maxPoints)) }

        // Periodic background save to reduce data loss on crash
        saveCounter += 1
        if saveCounter >= saveInterval {
            saveCounter = 0
            saveInBackground()
        }
    }

    // MARK: - Persistence

    private struct CacheData: Codable {
        var cpuHistory: [DataPoint]
        var cpuTempHistory: [DataPoint]
        var ramHistory: [DataPoint]
        var fanHistory: [DataPoint]
    }

    /// Save synchronously (called on app quit)
    func save() {
        performSave()
    }

    /// Save on background queue (called periodically)
    private func saveInBackground() {
        let cacheData = CacheData(
            cpuHistory: cpuHistory,
            cpuTempHistory: cpuTempHistory,
            ramHistory: ramHistory,
            fanHistory: fanHistory
        )
        let dir = cacheDir
        let file = cacheFile
        DispatchQueue.global(qos: .utility).async {
            Self.writeToDisk(cacheData: cacheData, cacheDir: dir, cacheFile: file)
        }
    }

    private func performSave() {
        let cacheData = CacheData(
            cpuHistory: cpuHistory,
            cpuTempHistory: cpuTempHistory,
            ramHistory: ramHistory,
            fanHistory: fanHistory
        )
        Self.writeToDisk(cacheData: cacheData, cacheDir: cacheDir, cacheFile: cacheFile)
    }

    private static func writeToDisk(cacheData: CacheData, cacheDir: URL, cacheFile: URL) {
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
