import Foundation
import IOKit

// MARK: - SMC Constants

private let kSMCUserClientOpen: UInt32 = 0
private let kSMCUserClientClose: UInt32 = 1
private let kSMCHandleYPCEvent: UInt32 = 2
private let kSMCReadKey: UInt8 = 5
private let kSMCGetKeyInfo: UInt8 = 9

// MARK: - SMC Data Structures (matches kernel driver layout)

struct SMCVersion {
    var major: CUnsignedChar = 0
    var minor: CUnsignedChar = 0
    var build: CUnsignedChar = 0
    var reserved: CUnsignedChar = 0
    var release: CUnsignedShort = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: IOByteCount = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCKeyData {
    typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

// MARK: - SMC Connection

final class SMCKit {
    static let shared = SMCKit()

    private var connection: io_connect_t = 0
    private(set) var isOpen = false

    private init() {}

    func open() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != 0 else {
            throw SMCError.driverNotFound
        }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else {
            throw SMCError.failedToOpen
        }
        isOpen = true
    }

    func close() {
        if isOpen {
            IOServiceClose(connection)
            isOpen = false
        }
    }

    // MARK: - Core Read

    private func callSMC(inputStruct: inout SMCKeyData) throws -> SMCKeyData {
        guard isOpen else { throw SMCError.failedToOpen }

        var outputStruct = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let result = IOConnectCallStructMethod(
            connection,
            kSMCHandleYPCEvent,
            &inputStruct, inputSize,
            &outputStruct, &outputSize
        )

        guard result == kIOReturnSuccess else {
            throw SMCError.readFailed("IOConnectCallStructMethod failed: \(result)")
        }

        return outputStruct
    }

    func readKey(_ key: String) throws -> SMCKeyData {
        var input = SMCKeyData()

        // Step 1: Get key info (data size + type)
        input.key = fourCharCode(key)
        input.data8 = kSMCGetKeyInfo

        let info = try callSMC(inputStruct: &input)

        // Step 2: Read the value
        input = SMCKeyData()
        input.key = fourCharCode(key)
        input.keyInfo.dataSize = info.keyInfo.dataSize
        input.data8 = kSMCReadKey

        return try callSMC(inputStruct: &input)
    }

    // MARK: - Temperature (sp78: signed 7.8 fixed point)

    func readTemperature(_ key: String) throws -> Double {
        let data = try readKey(key)
        let rawValue = (Int16(data.bytes.0) << 8) | Int16(data.bytes.1)
        let temp = Double(rawValue) / 256.0
        // Sanity check: ignore garbage values
        guard temp > 0 && temp < 150 else { return 0 }
        return temp
    }

    // MARK: - Fan Speed (fpe2: unsigned 14.2 fixed point)

    func readFanSpeed(_ fanIndex: Int) throws -> Double {
        let key = String(format: "F%dAc", fanIndex)
        let data = try readKey(key)
        let rawValue = (UInt16(data.bytes.0) << 8) | UInt16(data.bytes.1)
        return Double(rawValue) / 4.0
    }

    func readFanCount() throws -> Int {
        let data = try readKey("FNum")
        return Int(data.bytes.0)
    }

    func readFanMin(_ fanIndex: Int) throws -> Double {
        let key = String(format: "F%dMn", fanIndex)
        let data = try readKey(key)
        let rawValue = (UInt16(data.bytes.0) << 8) | UInt16(data.bytes.1)
        return Double(rawValue) / 4.0
    }

    func readFanMax(_ fanIndex: Int) throws -> Double {
        let key = String(format: "F%dMx", fanIndex)
        let data = try readKey(key)
        let rawValue = (UInt16(data.bytes.0) << 8) | UInt16(data.bytes.1)
        return Double(rawValue) / 4.0
    }

    // MARK: - Helpers

    private func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}

// MARK: - Errors

enum SMCError: LocalizedError {
    case driverNotFound
    case failedToOpen
    case keyNotFound(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .driverNotFound: return "AppleSMC driver not found"
        case .failedToOpen: return "Failed to open SMC connection"
        case .keyNotFound(let key): return "SMC key '\(key)' not found"
        case .readFailed(let key): return "Failed to read SMC key '\(key)'"
        }
    }
}
