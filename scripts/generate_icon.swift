#!/usr/bin/env swift
// Generates a 1024x1024 app icon for Rancage
// A modern gauge/dashboard icon with a temperature vibe

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

// Gradient background: dark charcoal
let bgGradient = NSGradient(
    starting: NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0),
    ending: NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
)!
bgGradient.draw(in: bgPath, angle: -90)

// Draw a gauge arc
let center = NSPoint(x: 512, y: 470)
let gaugeRadius: CGFloat = 300
let startAngle: CGFloat = 210
let endAngle: CGFloat = -30
let lineWidth: CGFloat = 40

// Background arc (dark)
let bgArc = NSBezierPath()
bgArc.appendArc(withCenter: center, radius: gaugeRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
bgArc.lineWidth = lineWidth
bgArc.lineCapStyle = .round
NSColor(red: 0.2, green: 0.22, blue: 0.26, alpha: 1.0).setStroke()
bgArc.stroke()

// Colored arc (gradient-like: green -> orange -> red)
// Draw as segments
let totalArcAngle: CGFloat = 240 // from 210 to -30
let segments = 60
let segmentAngle = totalArcAngle / CGFloat(segments)
let fillPercent: CGFloat = 0.7 // Show ~70% filled

for i in 0..<Int(CGFloat(segments) * fillPercent) {
    let t = CGFloat(i) / CGFloat(segments)
    let sAngle = startAngle - segmentAngle * CGFloat(i)
    let eAngle = sAngle - segmentAngle

    // Color interpolation: green -> cyan -> blue
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    if t < 0.5 {
        // green to cyan
        let u = t * 2
        r = 0.1 * (1 - u) + 0.1 * u
        g = 0.85 * (1 - u) + 0.75 * u
        b = 0.4 * (1 - u) + 0.95 * u
    } else {
        // cyan to orange/red
        let u = (t - 0.5) * 2
        r = 0.1 * (1 - u) + 0.95 * u
        g = 0.75 * (1 - u) + 0.4 * u
        b = 0.95 * (1 - u) + 0.2 * u
    }

    let segPath = NSBezierPath()
    segPath.appendArc(withCenter: center, radius: gaugeRadius, startAngle: sAngle, endAngle: eAngle, clockwise: true)
    segPath.lineWidth = lineWidth
    segPath.lineCapStyle = .butt
    NSColor(red: r, green: g, blue: b, alpha: 1.0).setStroke()
    segPath.stroke()
}

// Needle
let needleAngle: CGFloat = startAngle - totalArcAngle * fillPercent
let needleRad = needleAngle * .pi / 180
let needleLength: CGFloat = 200
let needleTip = NSPoint(
    x: center.x + needleLength * cos(needleRad),
    y: center.y + needleLength * sin(needleRad)
)

let needlePath = NSBezierPath()
needlePath.move(to: center)
needlePath.line(to: needleTip)
needlePath.lineWidth = 8
needlePath.lineCapStyle = .round
NSColor.white.setStroke()
needlePath.stroke()

// Center dot
let dotSize: CGFloat = 20
let dotRect = NSRect(x: center.x - dotSize/2, y: center.y - dotSize/2, width: dotSize, height: dotSize)
let dotPath = NSBezierPath(ovalIn: dotRect)
NSColor.white.setFill()
dotPath.fill()

// Small coffee cup indicator at bottom
let cupCenter = NSPoint(x: 512, y: 200)
let cupPath = NSBezierPath()
// Simple cup shape
cupPath.move(to: NSPoint(x: cupCenter.x - 30, y: cupCenter.y + 20))
cupPath.line(to: NSPoint(x: cupCenter.x - 22, y: cupCenter.y - 20))
cupPath.line(to: NSPoint(x: cupCenter.x + 22, y: cupCenter.y - 20))
cupPath.line(to: NSPoint(x: cupCenter.x + 30, y: cupCenter.y + 20))
cupPath.close()
cupPath.lineWidth = 5
NSColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.8).setStroke()
cupPath.stroke()

// Steam lines
for offset: CGFloat in [-10, 0, 10] {
    let steamPath = NSBezierPath()
    steamPath.move(to: NSPoint(x: cupCenter.x + offset, y: cupCenter.y + 24))
    steamPath.curve(
        to: NSPoint(x: cupCenter.x + offset, y: cupCenter.y + 55),
        controlPoint1: NSPoint(x: cupCenter.x + offset + 8, y: cupCenter.y + 32),
        controlPoint2: NSPoint(x: cupCenter.x + offset - 8, y: cupCenter.y + 47)
    )
    steamPath.lineWidth = 3
    steamPath.lineCapStyle = .round
    NSColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.5).setStroke()
    steamPath.stroke()
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
