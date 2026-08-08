import AppKit

/// Programmatic menu bar icons rendered as template images.
/// Template images only use the alpha channel — macOS handles
/// the actual fill color based on menu bar appearance (dark/light).
/// Visual reference: assets/icons/*.svg
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
        let img = NSImage(size: size, flipped: true) { rect in
            // For template images, we only care about alpha.
            // Draw everything in black — macOS replaces with appropriate color.
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Flip coordinate: since flipped=true, (0,0) is top-left
            switch self {
            case .cpu: Self.drawCPU(in: rect)
            case .thermometer: Self.drawThermometer(in: rect)
            case .memory: Self.drawMemory(in: rect)
            case .fan: Self.drawFan(in: rect)
            case .caffeine: Self.drawCaffeine(in: rect)
            case .caffeineOff: Self.drawCaffeineOff(in: rect)
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    // MARK: - CPU: chip with pins

    private static func drawCPU(in rect: NSRect) {
        let body = NSRect(x: 5, y: 5, width: 8, height: 8)
        let path = NSBezierPath(roundedRect: body, xRadius: 1.5, yRadius: 1.5)
        path.lineWidth = 1.3
        path.stroke()

        // Inner die
        let die = NSRect(x: 6.5, y: 6.5, width: 5, height: 5)
        NSBezierPath(roundedRect: die, xRadius: 0.5, yRadius: 0.5).fill()

        // Pins
        let pw: CGFloat = 1.2
        for x: CGFloat in [7, 9, 11] {
            line(from: NSPoint(x: x, y: 5), to: NSPoint(x: x, y: 2.5), width: pw)
            line(from: NSPoint(x: x, y: 13), to: NSPoint(x: x, y: 15.5), width: pw)
        }
        for y: CGFloat in [7, 9, 11] {
            line(from: NSPoint(x: 5, y: y), to: NSPoint(x: 2.5, y: y), width: pw)
            line(from: NSPoint(x: 13, y: y), to: NSPoint(x: 15.5, y: y), width: pw)
        }
    }

    // MARK: - Thermometer

    private static func drawThermometer(in rect: NSRect) {
        // Tube outline
        let tube = NSBezierPath()
        tube.move(to: NSPoint(x: 7.5, y: 3))
        tube.line(to: NSPoint(x: 7.5, y: 12))
        tube.move(to: NSPoint(x: 10.5, y: 3))
        tube.line(to: NSPoint(x: 10.5, y: 12))
        // Top cap
        tube.move(to: NSPoint(x: 7.5, y: 3))
        tube.appendArc(withCenter: NSPoint(x: 9, y: 3), radius: 1.5, startAngle: 180, endAngle: 0)
        tube.lineWidth = 1.2
        tube.lineCapStyle = .round
        tube.stroke()

        // Bulb
        let bulb = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 12, width: 5, height: 5))
        bulb.lineWidth = 1.2
        bulb.stroke()
        NSBezierPath(ovalIn: NSRect(x: 7.5, y: 13, width: 3, height: 3)).fill()

        // Mercury
        line(from: NSPoint(x: 9, y: 13), to: NSPoint(x: 9, y: 6), width: 1.8)

        // Ticks
        for y: CGFloat in [5, 7, 9] {
            line(from: NSPoint(x: 10.5, y: y), to: NSPoint(x: 12, y: y), width: 0.8)
        }
    }

    // MARK: - Memory (RAM stick)

    private static func drawMemory(in rect: NSRect) {
        let body = NSRect(x: 2, y: 6, width: 14, height: 7)
        let path = NSBezierPath(roundedRect: body, xRadius: 1.5, yRadius: 1.5)
        path.lineWidth = 1.2
        path.stroke()

        // Chips inside
        for x: CGFloat in [4.5, 7.5, 10.5] {
            NSBezierPath(rect: NSRect(x: x, y: 8, width: 2, height: 3)).fill()
        }

        // Pins bottom
        for x: CGFloat in [4, 6, 8, 10, 12, 14] {
            line(from: NSPoint(x: x, y: 13), to: NSPoint(x: x, y: 15), width: 1.0)
        }
    }

    // MARK: - Fan (3-blade propeller)

    private static func drawFan(in rect: NSRect) {
        let cx: CGFloat = 9, cy: CGFloat = 9

        // Center hub
        NSBezierPath(ovalIn: NSRect(x: cx - 1.8, y: cy - 1.8, width: 3.6, height: 3.6)).fill()

        // Outer circle
        let outer = NSBezierPath(ovalIn: NSRect(x: cx - 7, y: cy - 7, width: 14, height: 14))
        outer.lineWidth = 1.0
        outer.stroke()

        // 3 blades
        let angles: [CGFloat] = [90, 210, 330]
        for angle in angles {
            let rad = angle * .pi / 180
            let ctrlRad = (angle + 40) * .pi / 180

            let startX = cx + 2.2 * cos(rad)
            let startY = cy + 2.2 * sin(rad)
            let endX = cx + 6 * cos(rad)
            let endY = cy + 6 * sin(rad)
            let ctrlX = cx + 5 * cos(ctrlRad)
            let ctrlY = cy + 5 * sin(ctrlRad)

            let blade = NSBezierPath()
            blade.move(to: NSPoint(x: startX, y: startY))
            blade.curve(to: NSPoint(x: endX, y: endY),
                       controlPoint1: NSPoint(x: ctrlX, y: ctrlY),
                       controlPoint2: NSPoint(x: endX, y: endY))
            blade.lineWidth = 2.0
            blade.lineCapStyle = .round
            blade.stroke()
        }
    }

    // MARK: - Caffeine (coffee cup with steam)

    private static func drawCaffeine(in rect: NSRect) {
        // Cup body
        let cup = NSBezierPath()
        cup.move(to: NSPoint(x: 3, y: 7))
        cup.line(to: NSPoint(x: 4, y: 15))
        cup.line(to: NSPoint(x: 11, y: 15))
        cup.line(to: NSPoint(x: 12, y: 7))
        cup.lineWidth = 1.3
        cup.lineCapStyle = .round
        cup.lineJoinStyle = .round
        cup.stroke()

        // Handle
        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 12, y: 8))
        handle.curve(to: NSPoint(x: 12, y: 12.5),
                    controlPoint1: NSPoint(x: 15, y: 8),
                    controlPoint2: NSPoint(x: 15, y: 12.5))
        handle.lineWidth = 1.3
        handle.stroke()

        // Steam
        for xOff: CGFloat in [-2, 0, 2] {
            let steam = NSBezierPath()
            steam.move(to: NSPoint(x: 7.5 + xOff, y: 6.5))
            steam.curve(to: NSPoint(x: 7.5 + xOff, y: 2.5),
                       controlPoint1: NSPoint(x: 7.5 + xOff + 1.2, y: 5),
                       controlPoint2: NSPoint(x: 7.5 + xOff - 1.2, y: 4))
            steam.lineWidth = 0.9
            steam.lineCapStyle = .round
            steam.stroke()
        }
    }

    // MARK: - Caffeine Off (cup without steam, with Z)

    private static func drawCaffeineOff(in rect: NSRect) {
        // Cup body
        let cup = NSBezierPath()
        cup.move(to: NSPoint(x: 3, y: 7))
        cup.line(to: NSPoint(x: 4, y: 15))
        cup.line(to: NSPoint(x: 11, y: 15))
        cup.line(to: NSPoint(x: 12, y: 7))
        cup.lineWidth = 1.3
        cup.lineCapStyle = .round
        cup.lineJoinStyle = .round
        cup.stroke()

        // Handle
        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 12, y: 8))
        handle.curve(to: NSPoint(x: 12, y: 12.5),
                    controlPoint1: NSPoint(x: 15, y: 8),
                    controlPoint2: NSPoint(x: 15, y: 12.5))
        handle.lineWidth = 1.3
        handle.stroke()

        // "z" to indicate sleep allowed
        let z = NSBezierPath()
        z.move(to: NSPoint(x: 6, y: 3))
        z.line(to: NSPoint(x: 9.5, y: 3))
        z.line(to: NSPoint(x: 6, y: 6))
        z.line(to: NSPoint(x: 9.5, y: 6))
        z.lineWidth = 1.0
        z.lineCapStyle = .round
        z.lineJoinStyle = .round
        z.stroke()
    }

    // MARK: - Helper

    private static func line(from: NSPoint, to: NSPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }
}
