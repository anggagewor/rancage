import AppKit

/// Menu bar icons loaded from bundled PNG assets.
/// Images are set as template so macOS handles light/dark mode color.
/// Source PNGs: Sources/Resources/icon_*.png
enum MenuBarIcon {
    case cpu
    case thermometer
    case memory
    case fan
    case caffeine
    case caffeineOff

    /// Returns a proper template NSImage for use in menu bar.
    /// Template images auto-adapt to light/dark mode.
    var image: NSImage {
        let size = NSSize(width: 18, height: 18)

        guard let source = loadSource() else {
            // Fallback: return empty template image if resource missing
            let fallback = NSImage(size: size)
            fallback.isTemplate = true
            return fallback
        }

        // Resize to menu bar size
        let img = NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect,
                       from: NSRect(origin: .zero, size: source.size),
                       operation: .sourceOver,
                       fraction: 1.0)
            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: - Private

    private var resourceName: String {
        switch self {
        case .cpu: return "icon_cpu"
        case .thermometer: return "icon_thermometer"
        case .memory: return "icon_memory"
        case .fan: return "icon_fan"
        case .caffeine, .caffeineOff: return "icon_caffeine"
        }
    }

    private func loadSource() -> NSImage? {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
