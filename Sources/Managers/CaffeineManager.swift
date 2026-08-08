import Foundation
import IOKit.pwr_mgt

/// Prevents system sleep (Caffeine-like functionality)
final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    private var assertionID: IOPMAssertionID = 0
    @Published private(set) var isActive: Bool = false

    private init() {}

    /// Prevent system from sleeping
    @discardableResult
    func activate() -> Bool {
        guard !isActive else { return true }

        let reason = "Rancage: Keeping system awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isActive = true
            notifyChanged()
            return true
        }
        return false
    }

    /// Allow system to sleep again
    func deactivate() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
        notifyChanged()
    }

    @discardableResult
    func toggle() -> Bool {
        if isActive {
            deactivate()
        } else {
            activate()
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
