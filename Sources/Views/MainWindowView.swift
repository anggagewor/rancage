import SwiftUI

enum SidebarTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @State private var selectedTab: SidebarTab = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            // Fixed sidebar
            VStack(spacing: 0) {
                List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .listStyle(.sidebar)
            }
            .frame(width: 180)

            Divider()

            // Detail
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}
