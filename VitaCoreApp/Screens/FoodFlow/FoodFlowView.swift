// FoodFlowView.swift
// VitaCore – Food Photo Analysis Pipeline
// Root switcher that drives the stage machine and renders the correct screen.

import SwiftUI
import UIKit
import VitaCoreContracts
import VitaCoreDesign

struct FoodFlowView: View {

    @Environment(\.inferenceProvider) private var inferenceProvider
    @Environment(\.personaEngine) private var personaEngine
    @Environment(\.skillBus) private var skillBus
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FoodFlowViewModel?

    var body: some View {
        ZStack {
            if let vm = viewModel {
                currentStageView(vm: vm)
                    .animation(.easeInOut(duration: 0.35), value: vm.currentStage)
            } else {
                // Brief blank while ViewModel initialises (single frame).
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = FoodFlowViewModel(
                inferenceProvider: inferenceProvider,
                personaEngine: personaEngine,
                skillBus: skillBus
            )
        }
    }

    // MARK: - Stage Router

    @ViewBuilder
    private func currentStageView(vm: FoodFlowViewModel) -> some View {
        switch vm.currentStage {

        case .camera:
            CameraCaptureView(
                onImageCaptured: { image in
                    Task { await vm.handleImageCapture(image) }
                },
                onCancel: { dismiss() }
            )
            .transition(.opacity)

        case .qualityCheck(let report):
            QualityCheckView(
                image: vm.capturedImage,
                report: report,
                onRetake: { vm.retakePhoto() },
                onContinue: { vm.acceptLowQuality() }
            )
            .transition(.opacity)

        case .analysisLoading:
            AnalysisLoadingView(
                progress: vm.analysisProgress,
                statusText: vm.analysisStatusText
            )
            .transition(.opacity)

        case .allergenWarning(let warning):
            AllergenWarningView(
                warning: warning,
                onAcknowledge: { vm.acknowledgeAllergen() },
                onDiscard: { vm.discardFood() }
            )
            .transition(.opacity)

        case .medicationInteraction(let interaction):
            MedicationInteractionView(
                interaction: interaction,
                onAcknowledge: { vm.acknowledgeMedicationInteraction() },
                onDiscard: { vm.discardFood() }
            )
            .transition(.opacity)

        case .review(let result):
            FoodReviewView(
                result: result,
                editablePortions: Bindable(vm).editablePortions,
                onConfirm: { Task { await vm.confirmFood() } },
                onEdit: { id, grams in vm.updatePortion(for: id, grams: grams) },
                onCancel: { vm.discardFood() }
            )
            .transition(.opacity)

        case .confirmation(let result):
            FoodConfirmationView(
                result: result,
                onDone: { dismiss() }
            )
            .transition(.opacity)

        case .error(let message):
            errorView(message: message)
                .transition(.opacity)
        }
    }

    // MARK: - Error Fallback

    private func errorView(message: String) -> some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            GlassCard(style: .hero) {
                VStack(spacing: VCSpacing.xl) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(VCColors.critical)

                    VStack(spacing: VCSpacing.sm) {
                        Text("Something went wrong")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(VCColors.onSurface)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: VCRadius.pill)
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(VCSpacing.xxl)
            }
            .padding(.horizontal, VCSpacing.xl)
        }
    }
}
