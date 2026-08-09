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

// MARK: - Mode

enum CaffeineMode: String, Codable, CaseIterable {
    case preventSleep = "preventSleep"
    case preventDisplaySleep = "preventDisplaySleep"

    var label: String {
        switch self {
        case .preventSleep: return "Prevent Sleep"
        case .preventDisplaySleep: return "Prevent Sleep + Lock"
        }
    }

    var description: String {
        switch self {
        case .preventSleep: return "Mac won't sleep, but display can turn off & lock"
        case .preventDisplaySleep: return "Mac won't sleep, display stays on (no lock)"
        }
    }

    var assertionType: CFString {
        switch self {
        case .preventSleep:
            return kIOPMAssertPreventUserIdleSystemSleep as CFString
        case .preventDisplaySleep:
            return kIOPMAssertPreventUserIdleDisplaySleep as CFString
        }
    }
}

/// Prevents system sleep (Caffeine-like functionality).
/// State and mode are persisted to settings.json so they restore on relaunch.
final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    private var assertionID: IOPMAssertionID = 0
    @Published private(set) var isActive: Bool = false

    private init() {
        // Restore happens later via restoreState() called from AppDelegate
        // to avoid circular dependency during singleton initialization
    }

    /// Restore caffeine state from settings. Must be called AFTER all
    /// notification observers are set up and singletons are fully initialized.
    func restoreState() {
        if SettingsManager.shared.stayAwake {
            guard !isActive else { return }
            let mode = SettingsManager.shared.caffeineMode
            let reason = "Rancage: Keeping system awake" as CFString
            let result = IOPMAssertionCreateWithName(
                mode.assertionType,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            if result == kIOReturnSuccess {
                isActive = true
                // Don't notify here — caller will refresh UI after
            }
        }
    }

    /// Prevent system from sleeping using the configured mode
    @discardableResult
    func activate() -> Result<Void, CaffeineError> {
        guard !isActive else { return .failure(.alreadyActive) }

        let mode = SettingsManager.shared.caffeineMode
        let reason = "Rancage: Keeping system awake" as CFString
        let result = IOPMAssertionCreateWithName(
            mode.assertionType,
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

    /// Release assertion without persisting state (used on app quit)
    func releaseWithoutPersist() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
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

    /// Re-apply assertion with new mode (deactivate + activate)
    func reapplyMode() {
        guard isActive else { return }
        _ = deactivate()
        _ = activate()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .caffeineStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let caffeineStateChanged = Notification.Name("caffeineStateChanged")
}
