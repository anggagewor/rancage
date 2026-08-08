import SwiftUI

/// A lightweight line chart for historical data
struct MiniGraphView: View {
    let data: [Double]
    let color: Color
    let maxValue: Double?

    var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let effectiveMax = maxValue ?? (data.max() ?? 1)
                let effectiveMin: Double = 0
                let range = effectiveMax - effectiveMin
                let step = geo.size.width / CGFloat(max(data.count - 1, 1))

                ZStack {
                    // Background grid lines
                    VStack {
                        Divider()
                        Spacer()
                        Divider()
                        Spacer()
                        Divider()
                    }
                    .opacity(0.3)

                    // Fill area
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * step
                            let normalized = range > 0 ? (value - effectiveMin) / range : 0.5
                            let y = geo.size.height * (1 - CGFloat(normalized))
                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * step, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * step
                            let normalized = range > 0 ? (value - effectiveMin) / range : 0.5
                            let y = geo.size.height * (1 - CGFloat(normalized))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 1.5)
                }
            } else {
                // Not enough data yet
                HStack {
                    Spacer()
                    Text("Collecting data…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}
