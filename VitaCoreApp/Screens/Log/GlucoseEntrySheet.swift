// GlucoseEntrySheet.swift
// VitaCore — Glucose log entry bottom sheet

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

// MARK: - ViewModel

@Observable
@MainActor
final class GlucoseEntryViewModel {
    // Input
    var rawInput: String = ""
    var selectedUnit: GlucoseUnit = .mgdL
    var selectedContext: GlucoseContext = .random
    var selectedTime: Date = Date()

    // State
    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var saveError: String? = nil

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    // MARK: - Derived

    var parsedValue: Double? {
        guard let v = Double(rawInput), v > 0 else { return nil }
        return v
    }

    /// Always returns mg/dL for validation and submission
    var mgdLValue: Double? {
        guard let v = parsedValue else { return nil }
        switch selectedUnit {
        case .mgdL:   return v
        case .mmolL:  return v * 18.0182
        }
    }

    var isValidInput: Bool {
        guard let mg = mgdLValue else { return false }
        return mg >= 20 && mg <= 600
    }

    var validationMessage: String? {
        guard let v = parsedValue else { return nil }
        let mg: Double
        switch selectedUnit {
        case .mgdL:  mg = v
        case .mmolL: mg = v * 18.0182
        }
        if mg < 20  { return "Value too low — minimum 20 mg/dL (1.1 mmol/L)" }
        if mg > 600 { return "Value too high — maximum 600 mg/dL (33.3 mmol/L)" }
        return nil
    }

    var showHypoWarning: Bool {
        selectedContext == .hypoSymptom
    }

    // MARK: - Save

    func save(onDismiss: @escaping () -> Void) async {
        guard isValidInput, let mg = mgdLValue else { return }
        isSaving = true
        saveError = nil
        let result = await skillBus.logGlucose(value: mg, timestamp: selectedTime)
        isSaving = false
        if result.success {
            saveSuccess = true
            try? await Task.sleep(nanoseconds: 600_000_000)
            onDismiss()
        } else {
            saveError = result.message ?? "Failed to save. Please try again."
        }
    }
}

// MARK: - Supporting Types

enum GlucoseUnit: String, CaseIterable {
    case mgdL  = "mg/dL"
    case mmolL = "mmol/L"
}

enum GlucoseContext: String, CaseIterable, Identifiable {
    case fasting       = "Fasting"
    case preMeal       = "Pre-meal"
    case postMeal      = "Post-meal"
    case postExercise  = "Post-exercise"
    case bedtime       = "Bedtime"
    case random        = "Random"
    case hypoSymptom   = "Hypo symptom"

    var id: String { rawValue }
}

// MARK: - View

struct GlucoseEntrySheet: View {
    let onDismiss: () -> Void

    @Environment(\.skillBus) private var skillBus
    @State private var viewModel: GlucoseEntryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                GlucoseEntrySheetContent(viewModel: vm, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = GlucoseEntryViewModel(skillBus: skillBus)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(VCColors.background.ignoresSafeArea())
    }
}

// MARK: - Content

private struct GlucoseEntrySheetContent: View {
    @Bindable var viewModel: GlucoseEntryViewModel
    let onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    sheetHeader
                    valueInputSection
                    unitToggleSection
                    contextPickerSection
                    if viewModel.showHypoWarning { hypoWarningChip }
                    timePickerSection
                    if let err = viewModel.saveError { errorChip(message: err) }
                    saveButton
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, VCSpacing.xxxl)
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button("Cancel") { onDismiss() }
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(VCColors.primary)
                .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Text("Log Glucose")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VCColors.onSurface)

            Spacer()

            // Balance layout — invisible placeholder
            Button("Cancel") { }
                .font(.system(size: 16, weight: .regular))
                .opacity(0)
                .frame(minWidth: 44, minHeight: 44)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Value Input

    private var valueInputSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.sm) {
                Text("Reading")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .kerning(1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .lastTextBaseline, spacing: VCSpacing.sm) {
                    TextField("—", text: $viewModel.rawInput)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(inputColor)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .frame(maxWidth: .infinity)

                    Text(viewModel.selectedUnit.rawValue)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .padding(.bottom, 8)
                }

                if let msg = viewModel.validationMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VCColors.critical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                if viewModel.selectedUnit == .mmolL, let mg = viewModel.mgdLValue {
                    Text(String(format: "≈ %.0f mg/dL", mg))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
            .padding(VCSpacing.lg)
            .animation(.easeInOut(duration: 0.2), value: viewModel.validationMessage)
        }
        .onTapGesture { isInputFocused = true }
    }

    private var inputColor: Color {
        guard viewModel.parsedValue != nil else { return VCColors.onSurface }
        return viewModel.isValidInput ? VCColors.onSurface : VCColors.critical
    }

    // MARK: - Unit Toggle

    private var unitToggleSection: some View {
        Picker("Unit", selection: $viewModel.selectedUnit) {
            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                Text(unit.rawValue).tag(unit)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 44)
    }

    // MARK: - Context Picker

    private var contextPickerSection: some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            Text("CONTEXT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .kerning(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VCSpacing.sm) {
                    ForEach(GlucoseContext.allCases) { ctx in
                        contextPill(ctx)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func contextPill(_ ctx: GlucoseContext) -> some View {
        let isSelected = viewModel.selectedContext == ctx
        return Button {
            viewModel.selectedContext = ctx
        } label: {
            Text(ctx.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VCColors.primary : VCColors.onSurfaceVariant)
                .padding(.horizontal, VCSpacing.lg)
                .padding(.vertical, VCSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? VCColors.primaryContainer : VCColors.surfaceLow)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? VCColors.primary.opacity(0.4) : VCColors.outlineVariant,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    // MARK: - Hypo Warning

    private var hypoWarningChip: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VCColors.critical)

            Text("Critical context — will trigger immediate evaluation")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VCColors.critical)
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(VCColors.critical.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md)
                        .strokeBorder(VCColors.critical.opacity(0.25), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.showHypoWarning)
    }

    // MARK: - Time Picker

    private var timePickerSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                Text("TIME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .kerning(1.2)

                DatePicker(
                    "",
                    selection: $viewModel.selectedTime,
                    in: Date().addingTimeInterval(-43200)...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
            }
            .padding(VCSpacing.lg)
        }
    }

    // MARK: - Error Chip

    private func errorChip(message: String) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(VCColors.critical)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(VCColors.critical)
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(VCColors.critical.opacity(0.08))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await viewModel.save(onDismiss: onDismiss) }
        } label: {
            ZStack {
                if viewModel.saveSuccess {
                    Label("Saved", systemImage: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                } else if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if viewModel.isValidInput {
                        LinearGradient(
                            colors: [VCColors.primary, VCColors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [VCColors.onSurfaceVariant.opacity(0.3), VCColors.onSurfaceVariant.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: VCRadius.xl))
        }
        .disabled(!viewModel.isValidInput || viewModel.isSaving || viewModel.saveSuccess)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isValidInput)
    }
}
