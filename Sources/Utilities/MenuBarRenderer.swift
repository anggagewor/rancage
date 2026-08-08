import AppKit

/// Renders the status bar content as a single template NSImage.
/// Extracted from AppDelegate to reduce complexity.
final class MenuBarRenderer {

    private let iconSize: CGFloat = 14
    private let spacing: CGFloat = 3
    private let sectionSpacing: CGFloat = 8

    struct Part {
        let icon: MenuBarIcon?
        let text: String?
    }

    /// Build the list of parts based on current state and settings.
    func buildParts() -> [Part] {
        let state = MonitorState.shared
        let settings = SettingsManager.shared
        var parts: [Part] = []

        if settings.showFanInMenuBar, let fan = state.fanSpeeds.first {
            parts.append(Part(icon: .fan, text: String(format: "%4.0f", fan.rpm)))
        }
        if settings.showCPUTempInMenuBar && state.cpuTemp > 0 {
            parts.append(Part(icon: .thermometer, text: String(format: "%3.0f°", state.cpuTemp)))
        }
        if settings.showCPUInMenuBar {
            parts.append(Part(icon: .cpu, text: String(format: "%3.0f%%", state.cpuPercent)))
        }
        if settings.showRAMInMenuBar {
            parts.append(Part(icon: .memory, text: String(format: "%3.0f%%", state.memPercent)))
        }
        if settings.showCaffeineInMenuBar && CaffeineManager.shared.isActive {
            parts.append(Part(icon: .caffeine, text: nil))
        }

        return parts
    }

    /// Render parts into a single template NSImage for the status bar button.
    func render(parts: [Part], style: SettingsManager.MenuBarStyle) -> NSImage? {
        guard !parts.isEmpty else { return nil }

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let height: CGFloat = 18

        // Calculate total width
        var totalWidth: CGFloat = 0
        for (index, part) in parts.enumerated() {
            if index > 0 { totalWidth += sectionSpacing }
            let (showIcon, showText, forceIcon) = visibility(for: part, style: style)

            if showIcon || forceIcon { totalWidth += iconSize }
            if (showIcon || forceIcon) && showText { totalWidth += spacing }
            if showText, let text = part.text {
                totalWidth += (text as NSString).size(withAttributes: attrs).width
            }
        }

        let imgSize = NSSize(width: ceil(totalWidth), height: height)

        let img = NSImage(size: imgSize, flipped: false) { [self] _ in
            var x: CGFloat = 0

            for (index, part) in parts.enumerated() {
                if index > 0 { x += self.sectionSpacing }
                let (showIcon, showText, forceIcon) = self.visibility(for: part, style: style)

                if showIcon || forceIcon, let icon = part.icon {
                    let iconImg = icon.image
                    let iconRect = NSRect(x: x, y: (height - self.iconSize) / 2, width: self.iconSize, height: self.iconSize)
                    iconImg.draw(in: iconRect)
                    x += self.iconSize
                    if showText { x += self.spacing }
                }
                if showText, let text = part.text {
                    let textSize = (text as NSString).size(withAttributes: attrs)
                    let textY = (height - textSize.height) / 2
                    (text as NSString).draw(at: NSPoint(x: x, y: textY), withAttributes: attrs)
                    x += textSize.width
                }
            }
            return true
        }

        img.isTemplate = true
        return img
    }

    /// Determine visibility flags for a part
    private func visibility(for part: Part, style: SettingsManager.MenuBarStyle) -> (showIcon: Bool, showText: Bool, forceIcon: Bool) {
        let showIcon = (style == .icon || style == .both) && part.icon != nil
        let showText = (style == .text || style == .both) && part.text != nil
        let forceIcon = !showIcon && !showText && part.icon != nil
        return (showIcon, showText, forceIcon)
    }
}
