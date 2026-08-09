#!/usr/bin/env swift
// Generates a 1024x1024 app icon for Rancage
// macOS icon with proper inset (~15% padding from edges)

import AppKit
import CoreGraphics

let size = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Cannot create graphics context")
}

let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

// Background: rounded rectangle with dark gradient
let cornerRadius: CGFloat = 220
let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

let bgGradient = NSGradient(
    starting: NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0),
    ending: NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
)!
bgGradient.draw(in: bgPath, angle: -90)

// === Content area: inset 15% from each side ===
// This makes the icon visually match other macOS icons in size
let inset: CGFloat = 150
let contentCenter = NSPoint(x: 512, y: 520)
let gaugeRadius: CGFloat = 230
let startAngle: CGFloat = 210
let endAngle: CGFloat = -30
let lineWidth: CGFloat = 34
let totalArcAngle: CGFloat = 240

// Background arc (dark track)
let bgArc = NSBezierPath()
bgArc.appendArc(withCenter: contentCenter, radius: gaugeRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
bgArc.lineWidth = lineWidth
bgArc.lineCapStyle = .round
NSColor(red: 0.2, green: 0.22, blue: 0.26, alpha: 1.0).setStroke()
bgArc.stroke()

// Colored arc segments (green → cyan → warm)
let segments = 60
let segmentAngle = totalArcAngle / CGFloat(segments)
let fillPercent: CGFloat = 0.65

for i in 0..<Int(CGFloat(segments) * fillPercent) {
    let t = CGFloat(i) / CGFloat(segments)
    let sAngle = startAngle - segmentAngle * CGFloat(i)
    let eAngle = sAngle - segmentAngle

    let r: CGFloat, g: CGFloat, b: CGFloat
    if t < 0.5 {
        let u = t * 2
        r = 0.15 * (1 - u) + 0.1 * u
        g = 0.8 * (1 - u) + 0.75 * u
        b = 0.4 * (1 - u) + 0.9 * u
    } else {
        let u = (t - 0.5) * 2
        r = 0.1 * (1 - u) + 0.3 * u
        g = 0.75 * (1 - u) + 0.85 * u
        b = 0.9 * (1 - u) + 0.95 * u
    }

    let segPath = NSBezierPath()
    segPath.appendArc(withCenter: contentCenter, radius: gaugeRadius, startAngle: sAngle, endAngle: eAngle, clockwise: true)
    segPath.lineWidth = lineWidth
    segPath.lineCapStyle = .butt
    NSColor(red: r, green: g, blue: b, alpha: 1.0).setStroke()
    segPath.stroke()
}

// Needle
let needleAngle: CGFloat = startAngle - totalArcAngle * fillPercent
let needleRad = needleAngle * .pi / 180
let needleLength: CGFloat = 160
let needleTip = NSPoint(
    x: contentCenter.x + needleLength * cos(needleRad),
    y: contentCenter.y + needleLength * sin(needleRad)
)

let needlePath = NSBezierPath()
needlePath.move(to: contentCenter)
needlePath.line(to: needleTip)
needlePath.lineWidth = 7
needlePath.lineCapStyle = .round
NSColor.white.setStroke()
needlePath.stroke()

// Center hub
let hubSize: CGFloat = 18
let hubRect = NSRect(x: contentCenter.x - hubSize/2, y: contentCenter.y - hubSize/2, width: hubSize, height: hubSize)
NSColor.white.setFill()
NSBezierPath(ovalIn: hubRect).fill()

// Coffee cup at bottom center (smaller, subtle)
let cupCenter = NSPoint(x: 512, y: 260)
let cupScale: CGFloat = 0.7

let cupPath = NSBezierPath()
cupPath.move(to: NSPoint(x: cupCenter.x - 22 * cupScale, y: cupCenter.y + 14 * cupScale))
cupPath.line(to: NSPoint(x: cupCenter.x - 16 * cupScale, y: cupCenter.y - 14 * cupScale))
cupPath.line(to: NSPoint(x: cupCenter.x + 16 * cupScale, y: cupCenter.y - 14 * cupScale))
cupPath.line(to: NSPoint(x: cupCenter.x + 22 * cupScale, y: cupCenter.y + 14 * cupScale))
cupPath.close()
cupPath.lineWidth = 4
NSColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.7).setStroke()
cupPath.stroke()

// Steam
for offset: CGFloat in [-7, 0, 7] {
    let steam = NSBezierPath()
    steam.move(to: NSPoint(x: cupCenter.x + offset, y: cupCenter.y + 16 * cupScale))
    steam.curve(
        to: NSPoint(x: cupCenter.x + offset, y: cupCenter.y + 42 * cupScale),
        controlPoint1: NSPoint(x: cupCenter.x + offset + 5, y: cupCenter.y + 24 * cupScale),
        controlPoint2: NSPoint(x: cupCenter.x + offset - 5, y: cupCenter.y + 34 * cupScale)
    )
    steam.lineWidth = 2.5
    steam.lineCapStyle = .round
    NSColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.4).setStroke()
    steam.stroke()
}

NSGraphicsContext.current = nil

// Save as PNG
guard let cgImage = context.makeImage() else {
    fatalError("Cannot create image")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Cannot create PNG data")
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets/logo.png"

let url = URL(fileURLWithPath: outputPath)
try! pngData.write(to: url)
print("✅ Icon generated: \(url.path)")
