import SwiftUI
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation
import VitaCoreMock

// MARK: - ContentView

struct ContentView: View {

    @Environment(TabRouter.self) var tabRouter
    @Environment(NavigationRouter.self) var navRouter
    @Environment(AlertPresentationManager.self) var alertManager

    var body: some View {
        ZStack {
            // Background mesh behind all content
            BackgroundMesh()
                .ignoresSafeArea()

            // Main tab view
            TabView(selection: Bindable(tabRouter).selectedTab) {

                // Tab 1: Home
                NavigationStack(path: Bindable(navRouter).homePath) {
                    HomeDashboardView()
                        .navigationDestination(for: AppDestination.self) { destination in
                            switch destination {
                            case .glucoseDetail:    GlucoseDetailView()
                            case .bpDetail:         BloodPressureDetailView()
                            case .hrDetail:         HeartRateDetailView()
                            case .stepsDetail:      StepsDetailView()
                            case .sleepDetail:      SleepDetailView()
                            case .goalDetail:       GoalDetailView()
                            case .monitoringDetail: MonitoringDetailView()
                            case .userProfile:      ProfileSettingsView()
                            default:                Text("Coming soon")
                                                        .font(.title2)
                                                        .foregroundStyle(VCColors.onSurfaceVariant)
                            }
                        }
                }
                .tabItem { Label(VCTab.home.title, systemImage: VCTab.home.icon) }
                .tag(VCTab.home)

                // Tab 2: Chat
                NavigationStack {
                    ChatView()
                }
                .tabItem { Label(VCTab.chat.title, systemImage: VCTab.chat.icon) }
                .tag(VCTab.chat)

                // Tab 3: Log (centre action tab)
                NavigationStack {
                    LogHubView()
                }
                .tabItem { Label(VCTab.log.title, systemImage: VCTab.log.icon) }
                .tag(VCTab.log)

                // Tab 4: Alerts
                NavigationStack {
                    AlertHistoryView()
                }
                .tabItem { Label(VCTab.alerts.title, systemImage: VCTab.alerts.icon) }
                .tag(VCTab.alerts)

                // Tab 5: Settings
                NavigationStack {
                    SettingsMainView()
                }
                .tabItem { Label(VCTab.settings.title, systemImage: VCTab.settings.icon) }
                .tag(VCTab.settings)
            }
            .tint(VCColors.primary)
            .sensoryFeedback(.selection, trigger: tabRouter.selectedTab)

            // WATCH banner overlay — slides in from top
            if let banner = alertManager.activeWatchBanner {
                VStack {
                    WatchBannerView(data: banner)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: alertManager.activeWatchBanner != nil)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: alertManager.activeWatchBanner != nil)

        // CRITICAL alert full-screen cover
        .fullScreenCover(item: Bindable(alertManager).activeCriticalAlert) { data in
            CriticalAlertView(data: data)
        }

        // ALERT bottom sheet
        .sheet(item: Bindable(alertManager).activeAlertSheet) { data in
            AlertSheetView(data: data)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }

        // Deep-link handling
        .onOpenURL { url in
            DeepLinkHandler.handle(url: url, tabRouter: tabRouter, navRouter: navRouter)
        }
    }
}

// MARK: - Previews

#Preview("Content View") {
    ContentView()
        .environment(TabRouter())
        .environment(NavigationRouter())
        .environment(AlertPresentationManager())
        .environment(\.alertRouter, MockAlertRouter())
}
