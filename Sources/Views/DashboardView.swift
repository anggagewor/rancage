import SwiftUI

struct DashboardView: View {
    @ObservedObject private var state = MonitorState.shared
    @ObservedObject private var history = HistoryStore.shared
    @ObservedObject private var caffeine = CaffeineManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // CPU Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("CPU")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1f%%", state.cpuPercent))
                                .font(.title2.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                        ProgressView(value: min(state.cpuPercent, 100), total: 100)
                            .tint(.blue)

                        MiniGraphView(
                            data: history.cpuHistory.map(\.value),
                            color: .blue,
                            maxValue: 100
                        )
                        .frame(height: 60)

                        if state.cpuTemp > 0 {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .foregroundColor(tempColor(state.cpuTemp))
                                Text("Temperature")
                                Spacer()
                                Text(String(format: "%.1f°C", state.cpuTemp))
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(tempColor(state.cpuTemp))
                            }
                            MiniGraphView(
                                data: history.cpuTempHistory.map(\.value),
                                color: tempColor(state.cpuTemp),
                                maxValue: 105
                            )
                            .frame(height: 40)
                        }
                    }
                    .padding(4)
                }

                // Memory Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.green)
                            Text("Memory")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1f%%", state.memPercent))
                                .font(.title2.monospacedDigit())
                                .foregroundColor(.green)
                        }
                        ProgressView(value: min(state.memPercent, 100), total: 100)
                            .tint(.green)

                        MiniGraphView(
                            data: history.ramHistory.map(\.value),
                            color: .green,
                            maxValue: 100
                        )
                        .frame(height: 60)

                        Text(String(format: "%.1f GB used of %.1f GB", state.memUsedGB, state.memTotalGB))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                }

                // Fans Section
                if !state.fanSpeeds.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "fan")
                                    .foregroundColor(.orange)
                                Text("Fans")
                                    .font(.headline)
                                Spacer()
                            }
                            ForEach(Array(state.fanSpeeds.enumerated()), id: \.offset) { _, fan in
                                HStack {
                                    let label = state.fanSpeeds.count == 1 ? "Fan" : "Fan \(fan.index)"
                                    Text(label)
                                    Spacer()
                                    Text(String(format: "%.0f RPM", fan.rpm))
                                        .font(.body.monospacedDigit())
                                }
                            }
                            MiniGraphView(
                                data: history.fanHistory.map(\.value),
                                color: .orange,
                                maxValue: nil
                            )
                            .frame(height: 60)
                        }
                        .padding(4)
                    }
                }

                // Caffeine Section
                GroupBox {
                    HStack {
                        Image(systemName: caffeine.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .foregroundColor(caffeine.isActive ? .orange : .secondary)
                        Text("Stay Awake")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { caffeine.isActive },
                            set: { _ in caffeine.toggle() }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding(4)
                }
            }
            .padding()
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp >= 90 { return .red }
        if temp >= 70 { return .orange }
        return .green
    }
}
