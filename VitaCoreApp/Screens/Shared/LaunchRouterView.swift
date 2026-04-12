// LaunchRouterView.swift
// VitaCoreApp — Root view that routes to Onboarding or the main app.
//
// Reads the persisted `hasCompletedOnboarding` flag on launch and
// shows OnboardingFlowCoordinator on first run, ContentView thereafter.
// The animated transition fires once when the flag flips to true.

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation

struct LaunchRouterView: View {
    @AppStorage("vitacore.hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showMainApp: Bool = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding || showMainApp {
                ContentView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingFlowCoordinator(onComplete: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        hasCompletedOnboarding = true
                        showMainApp = true
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
    }
}

#if DEBUG
#Preview("Onboarding") {
    LaunchRouterView()
}
#endif
