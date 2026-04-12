// OnboardingFlowCoordinator.swift
// VitaCoreApp — Root coordinator for the 8-step onboarding flow.
//
// Owns the current step state and renders the correct screen.
// All navigation (next / back / skip) is handled here so individual
// screens remain pure presentation views.

import SwiftUI
import VitaCoreDesign

// MARK: - OnboardingStep

/// An ordered enum covering all 8 onboarding screens.
enum OnboardingStep: Int, CaseIterable {
    case welcome          = 1   // OB-01
    case basicProfile     = 2   // OB-02
    case conditions       = 3   // OB-03
    case goals            = 4   // OB-04
    case medications      = 5   // OB-05
    case allergies        = 6   // OB-06
    case permissions      = 7   // OB-07
    case download         = 8   // OB-08
}

// MARK: - OnboardingFlowCoordinator

/// Top-level view that drives the VitaCore onboarding experience.
///
/// Inject this as the root view when the user has not yet completed onboarding.
///
/// ```swift
/// OnboardingFlowCoordinator(onComplete: { appState.isOnboarded = true })
/// ```
struct OnboardingFlowCoordinator: View {

    // -------------------------------------------------------------------------
    // MARK: External
    // -------------------------------------------------------------------------

    /// Called when OB-08 (Download) signals that the model is ready
    /// and the user taps "Start Using VitaCore".
    let onComplete: () -> Void

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var currentStep: OnboardingStep = .welcome

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        ZStack {
            switch currentStep {

            // ── OB-01: Welcome ────────────────────────────────────────────────
            case .welcome:
                OnboardingWelcomeView(
                    onNext: { advance() }
                )
                .transition(forwardTransition)

            // ── OB-02: Basic Profile ──────────────────────────────────────────
            case .basicProfile:
                OnboardingBasicProfileView(
                    onNext: { advance() },
                    onBack: { retreat() }
                )
                .transition(forwardTransition)

            // ── OB-03: Conditions ─────────────────────────────────────────────
            case .conditions:
                OnboardingConditionsView(
                    onNext: { advance() },
                    onBack: { retreat() },
                    onSkip: { advance() }
                )
                .transition(forwardTransition)

            // ── OB-04: Goals ──────────────────────────────────────────────────
            case .goals:
                OnboardingGoalsView(
                    onNext: { advance() },
                    onBack: { retreat() },
                    onSkip: { advance() }
                )
                .transition(forwardTransition)

            // ── OB-05: Medications ────────────────────────────────────────────
            case .medications:
                OnboardingMedicationsView(
                    onNext: { advance() },
                    onBack: { retreat() },
                    onSkip: { advance() }
                )
                .transition(forwardTransition)

            // ── OB-06: Allergies ──────────────────────────────────────────────
            case .allergies:
                OnboardingAllergiesView(
                    onNext: { advance() },
                    onBack: { retreat() },
                    onSkip: { advance() }
                )
                .transition(forwardTransition)

            // ── OB-07: Permissions ────────────────────────────────────────────
            case .permissions:
                OnboardingPermissionsView(
                    onNext: { advance() },
                    onBack: { retreat() }
                )
                .transition(forwardTransition)

            // ── OB-08: Download ───────────────────────────────────────────────
            case .download:
                OnboardingDownloadView(
                    onComplete: onComplete
                )
                .transition(forwardTransition)
            }
        }
        .animation(VCAnimation.cardEntrance, value: currentStep)
    }

    // -------------------------------------------------------------------------
    // MARK: Navigation Helpers
    // -------------------------------------------------------------------------

    /// Move to the next step in the flow.
    private func advance() {
        guard let next = nextStep(after: currentStep) else {
            // Already at the last step; the download screen handles its own completion.
            return
        }
        withAnimation(VCAnimation.cardEntrance) {
            currentStep = next
        }
    }

    /// Move back to the previous step.
    private func retreat() {
        guard let previous = previousStep(before: currentStep) else { return }
        withAnimation(VCAnimation.cardEntrance) {
            currentStep = previous
        }
    }

    /// Returns the step that follows `step`, or nil if at the end.
    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    /// Returns the step that precedes `step`, or nil if at the beginning.
    private func previousStep(before step: OnboardingStep) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step), idx > 0 else { return nil }
        return all[idx - 1]
    }

    // -------------------------------------------------------------------------
    // MARK: Transitions
    // -------------------------------------------------------------------------

    private var forwardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Full Onboarding Flow") {
    OnboardingFlowCoordinator(onComplete: {
        print("Onboarding complete!")
    })
}

#Preview("Start at Medications (OB-05)") {
    // Convenience preview to jump directly to OB-05
    OnboardingMedicationsView(
        onNext: {},
        onBack: {},
        onSkip: {}
    )
}

#Preview("Start at Allergies (OB-06)") {
    OnboardingAllergiesView(
        onNext: {},
        onBack: {},
        onSkip: {}
    )
}

#Preview("Start at Permissions (OB-07)") {
    OnboardingPermissionsView(
        onNext: {},
        onBack: {}
    )
}

#Preview("Start at Download (OB-08)") {
    OnboardingDownloadView(onComplete: {})
}
#endif
