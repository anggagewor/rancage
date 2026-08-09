import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Menu Bar Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Menu Bar", systemImage: "menubar.rectangle")
                            .font(.headline)

                        Toggle("CPU Usage", isOn: $settings.showCPUInMenuBar)
                        Toggle("CPU Temperature", isOn: $settings.showCPUTempInMenuBar)
                        Toggle("RAM Usage", isOn: $settings.showRAMInMenuBar)
                        Toggle("Fan Speed", isOn: $settings.showFanInMenuBar)
                        Toggle("Caffeine Status", isOn: $settings.showCaffeineInMenuBar)

                        Divider()

                        Picker("Display Style", selection: $settings.menuBarStyle) {
                            ForEach(SettingsManager.MenuBarStyle.allCases, id: \.self) { style in
                                Text(style.label).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(4)
                }

                // Alerts Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Alerts", systemImage: "bell")
                            .font(.headline)

                        Toggle("Enable Notifications", isOn: $settings.alertsEnabled)

                        if settings.alertsEnabled {
                            HStack {
                                Text("Temperature Threshold")
                                Spacer()
                                Picker("", selection: $settings.tempAlertThreshold) {
                                    Text("80°C").tag(80.0)
                                    Text("85°C").tag(85.0)
                                    Text("90°C").tag(90.0)
                                    Text("95°C").tag(95.0)
                                    Text("100°C").tag(100.0)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 280)
                            }

                            HStack {
                                Text("RAM Threshold")
                                Spacer()
                                Picker("", selection: $settings.ramAlertThreshold) {
                                    Text("80%").tag(80.0)
                                    Text("85%").tag(85.0)
                                    Text("90%").tag(90.0)
                                    Text("95%").tag(95.0)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 220)
                            }

                            Text("Notifications are throttled to max 1 per minute.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                }

                // General Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("General", systemImage: "gearshape")
                            .font(.headline)

                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("", selection: $settings.refreshInterval) {
                                Text("1s").tag(1.0)
                                Text("2s").tag(2.0)
                                Text("3s").tag(3.0)
                                Text("5s").tag(5.0)
                                Text("10s").tag(10.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 250)
                        }
                        .onChange(of: settings.refreshInterval) { _, _ in
                            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
                        }

                        Divider()

                        Toggle("Show Dock Icon", isOn: $settings.showDockIcon)
                            .help("When disabled, Rancage only appears in the menu bar")
                    }
                    .padding(4)
                }

                // Info Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Storage", systemImage: "folder")
                            .font(.headline)

                        HStack {
                            Text("Settings")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("~/.config/rancage/settings.json")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("History Cache")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("~/.cache/rancage/history.json")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                }
            }
            .padding()
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
}
