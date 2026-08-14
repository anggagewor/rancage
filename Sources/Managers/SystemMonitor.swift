import Foundation

// MARK: - System Resource Monitor

final class SystemMonitor {
    static let shared = SystemMonitor()

    private var previousCPUInfo: host_cpu_load_info?

    /// Cached host port — avoids leaking a new send right on every call.
    private let hostPort: mach_port_t

    private init() {
        hostPort = mach_host_self()
    }

    // MARK: - CPU Usage

    func cpuUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(
                    hostPort,
                    HOST_CPU_LOAD_INFO,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0.0 }

        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3)

        if let prev = previousCPUInfo {
            let userDiff = user - Double(prev.cpu_ticks.0)
            let systemDiff = system - Double(prev.cpu_ticks.1)
            let idleDiff = idle - Double(prev.cpu_ticks.2)
            let niceDiff = nice - Double(prev.cpu_ticks.3)

            let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
            guard totalTicks > 0 else {
                previousCPUInfo = cpuInfo
                return 0.0
            }

            let usage = ((userDiff + systemDiff + niceDiff) / totalTicks) * 100.0
            previousCPUInfo = cpuInfo
            return usage
        }

        previousCPUInfo = cpuInfo
        let totalTicks = user + system + idle + nice
        guard totalTicks > 0 else { return 0.0 }
        return ((user + system + nice) / totalTicks) * 100.0
    }

    // MARK: - Memory Usage

    struct MemoryUsage {
        let used: UInt64
        let total: UInt64
        var percentage: Double {
            guard total > 0 else { return 0 }
            return Double(used) / Double(total) * 100.0
        }
        var usedGB: Double { Double(used) / 1_073_741_824 }
        var totalGB: Double { Double(total) / 1_073_741_824 }
    }

    func memoryUsage() -> MemoryUsage {
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    hostPort,
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryUsage(used: 0, total: totalMemory)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        return MemoryUsage(used: used, total: totalMemory)
    }
}
