import Foundation
import IOKit.pwr_mgt

// MARK: - Errors

enum CaffeineError: LocalizedError {
    case assertionFailed(kern_return_t)
    case alreadyActive
    case notActive

    var errorDescription: String? {
        switch self {
        case .assertionFailed(let code):
            return "IOPMAssertion failed with code: \(code)"
        case .alreadyActive:
            return "Sleep prevention is already active"
        case .notActive:
            return "Sleep prevention is not active"
        }
    }
}

/// Prevents system sleep (Caffeine-like functionality).
/// State is persisted to settings.json so it restores on relaunch.
final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    private var assertionID: IOPMAssertionID = 0
    @Published private(set) var isActive: Bool = false

    private init() {
        // Restore from settings
        if SettingsManager.shared.stayAwake {
            _ = activate()
        }
    }

    /// Prevent system from sleeping
    @discardableResult
    func activate() -> Result<Void, CaffeineError> {
        guard !isActive else { return .failure(.alreadyActive) }

        let reason = "Rancage: Keeping system awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            return .failure(.assertionFailed(result))
        }

        isActive = true
        SettingsManager.shared.stayAwake = true
        notifyChanged()
        return .success(())
    }

    /// Allow system to sleep again
    @discardableResult
    func deactivate() -> Result<Void, CaffeineError> {
        guard isActive else { return .failure(.notActive) }

        let result = IOPMAssertionRelease(assertionID)
        guard result == kIOReturnSuccess else {
            return .failure(.assertionFailed(result))
        }

        assertionID = 0
        isActive = false
        SettingsManager.shared.stayAwake = false
        notifyChanged()
        return .success(())
    }

    /// Toggle sleep prevention state
    @discardableResult
    func toggle() -> Bool {
        if isActive {
            _ = deactivate()
        } else {
            _ = activate()
        }
        return isActive
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .caffeineStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let caffeineStateChanged = Notification.Name("caffeineStateChanged")
}
