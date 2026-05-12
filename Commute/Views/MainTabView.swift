import SwiftUI

enum MainTab: Hashable, CaseIterable {
    case home, plan, fares, alerts

    var label: String {
        // Use NSLocalizedString explicitly so the lookup goes through the
        // swizzled Bundle.main path. (String(localized:) appears to bypass
        // our override in some configurations.)
        switch self {
        case .home:   NSLocalizedString("Home", comment: "")
        case .plan:   NSLocalizedString("Plan", comment: "")
        case .fares:  NSLocalizedString("Fares", comment: "")
        case .alerts: NSLocalizedString("Alerts", comment: "")
        }
    }

    var symbol: String {
        switch self {
        case .home:   "house.fill"
        case .plan:   "point.topleft.down.curvedto.point.bottomright.up"
        case .fares:  "function"
        case .alerts: "bell.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selection: MainTab = .home
    /// Lifted to the tab-bar level so the Alerts badge can reflect the real
    /// live disruption count, and so the data is fetched even before the user
    /// opens the Alerts tab.
    @State private var alertsViewModel = AlertsViewModel()

    var body: some View {
        // iOS 26 renders the standard `TabView` as a floating Liquid Glass
        // capsule automatically — selected tab gets a filled inner pill and
        // the bar floats over content. The custom container we tried earlier
        // (sliding cross-tab transitions) produced inconsistent direction
        // perception (Home→Alerts went right, Alerts→Plan went left, etc.)
        // and broke the native glass look. The native chrome is the right
        // call here; Apple's transition is intentionally instant.
        TabView(selection: $selection) {
            HomeView(selectedTab: $selection)
                .tabItem { Label(MainTab.home.label, systemImage: MainTab.home.symbol) }
                .tag(MainTab.home)

            PlanView()
                .tabItem { Label(MainTab.plan.label, systemImage: MainTab.plan.symbol) }
                .tag(MainTab.plan)

            FaresView()
                .tabItem { Label(MainTab.fares.label, systemImage: MainTab.fares.symbol) }
                .tag(MainTab.fares)

            AlertsView(viewModel: alertsViewModel)
                .tabItem { Label(MainTab.alerts.label, systemImage: MainTab.alerts.symbol) }
                .tag(MainTab.alerts)
                .badge(alertsViewModel.disruptions.count)
        }
        .task { await alertsViewModel.refresh() }
    }
}
