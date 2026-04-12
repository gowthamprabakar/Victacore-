// BPEntrySheet.swift
// VitaCore — Blood pressure log entry bottom sheet

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

// MARK: - BP Classification

enum BPClassification {
    case normal, elevated, stage1, stage2, crisis

    static func classify(systolic: Double, diastolic: Double) -> BPClassification {
        if systolic >= 180 || diastolic >= 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90  { return .stage2 }
        if systolic >= 130 || diastolic >= 80  { return .stage1 }
        if systolic >= 120 && diastolic < 80   { return .elevated }
        return .normal
    }

    var label: String {
        switch self {
        case .normal:   return "Normal"
        case .elevated: return "Elevated"
        case .stage1:   return "Stage 1 Hypertension"
        case .stage2:   return "Stage 2 Hypertension"
        case .crisis:   return "Hypertensive Crisis"
        }
    }

    var color: Color {
        switch self {
        case .normal:   return VCColors.safe
        case .elevated: return VCColors.watch
        case .stage1:   return Color(red: 0.95, green: 0.60, blue: 0.10)  // amber
        case .stage2:   return VCColors.alertOrange
        case .crisis:   return VCColors.critical
        }
    }

    var icon: String {
        switch self {
        case .normal:   return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.circle"
        case .stage1:   return "exclamationmark.circle.fill"
        case .stage2:   return "exclamationmark.triangle"
        case .crisis:   return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - BP Context

enum BPContext: String, CaseIterable, Identifiable {
    case resting      = "Resting"
    case morning      = "Morning"
    case postExercise = "Post-exercise"
    case standing     = "Standing"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
@MainActor
final class BPEntryViewModel {
    var systolicInput: String = ""
    var diastolicInput: String = ""
    var pulseInput: String = ""
    var selectedContext: BPContext = .resting
    var selectedTime: Date = Date()

    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var saveError: String? = nil

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    var parsedSystolic: Double? {
        guard let v = Double(systolicInput), v > 0 else { return nil }
        return v
    }

    var parsedDiastolic: Double? {
        guard let v = Double(diastolicInput), v > 0 else { return nil }
        return v
    }

    var classification: BPClassification? {
        guard let sys = parsedSystolic, let dia = parsedDiastolic else { return nil }
        return BPClassification.classify(systolic: sys, diastolic: dia)
    }

    var validationError: String? {
        guard let sys = parsedSystolic, let dia = parsedDiastolic else { return nil }
        if dia >= sys { return "Diastolic must be less than systolic" }
        if sys < 50 || sys > 300 { return "Systolic out of range (50–300 mmHg)" }
        if dia < 30 || dia > 200 { return "Diastolic out of range (30–200 mmHg)" }
        return nil
    }

    var isValidInput: Bool {
        guard parsedSystolic != nil, parsedDiastolic != nil else { return false }
        return validationError == nil
    }

    func save(onDismiss: @escaping () -> Void) async {
        guard isValidInput, let sys = parsedSystolic, let dia = parsedDiastolic else { return }
        isSaving = true
        saveError = nil
        let result = await skillBus.logBloodPressure(systolic: sys, diastolic: dia, timestamp: selectedTime)
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

// MARK: - View

struct BPEntrySheet: View {
    let onDismiss: () -> Void

    @Environment(\.skillBus) private var skillBus
    @State private var viewModel: BPEntryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                BPEntrySheetContent(viewModel: vm, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BPEntryViewModel(skillBus: skillBus)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(VCColors.background.ignoresSafeArea())
    }
}

// MARK: - Content

private struct BPEntrySheetContent: View {
    @Bindable var viewModel: BPEntryViewModel
    let onDismiss: () -> Void

    @FocusState private var focusedField: BPField?

    enum BPField { case systolic, diastolic, pulse }

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    sheetHeader
                    bpInputSection
                    if let cls = viewModel.classification { classificationPreview(cls) }
                    if let err = viewModel.validationError { validationChip(message: err) }
                    contextPickerSection
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

            Text("Log Blood Pressure")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VCColors.onSurface)

            Spacer()

            Button("Cancel") { }
                .font(.system(size: 16, weight: .regular))
                .opacity(0)
                .frame(minWidth: 44, minHeight: 44)
                .allowsHitTesting(false)
        }
    }

    // MARK: - BP Input

    private var bpInputSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.lg) {
                // Systolic / Diastolic row
                HStack(alignment: .center, spacing: 0) {
                    bpField(
                        label: "Systolic",
                        placeholder: "—",
                        text: $viewModel.systolicInput,
                        field: .systolic
                    )

                    Text("/")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .frame(width: 28)

                    bpField(
                        label: "Diastolic",
                        placeholder: "—",
                        text: $viewModel.diastolicInput,
                        field: .diastolic
                    )

                    Text("mmHg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .padding(.leading, VCSpacing.sm)
                        .padding(.bottom, 20)
                }

                Divider()
                    .background(VCColors.outlineVariant)

                // Optional Pulse
                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(VCColors.secondary)

                    Text("Pulse (optional)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)

                    Spacer()

                    TextField("—", text: $viewModel.pulseInput)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(VCColors.onSurface)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .pulse)
                        .frame(width: 60)
                        .frame(minHeight: 44)

                    Text("bpm")
                        .font(.system(size: 13))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
            }
            .padding(VCSpacing.lg)
        }
    }

    private func bpField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: BPField
    ) -> some View {
        VStack(spacing: VCSpacing.xs) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .kerning(0.8)

            TextField(placeholder, text: text)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
    }

    // MARK: - Classification Preview

    private func classificationPreview(_ cls: BPClassification) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: cls.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(cls.color)

            Text(cls.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(cls.color)

            Spacer()
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(cls.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md)
                        .strokeBorder(cls.color.opacity(0.25), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: cls.label)
    }

    // MARK: - Validation Chip

    private func validationChip(message: String) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(VCColors.critical)
            Text(message)
                .font(.system(size: 13, weight: .medium))
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

    // MARK: - Context Picker

    private var contextPickerSection: some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            Text("CONTEXT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .kerning(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VCSpacing.sm) {
                    ForEach(BPContext.allCases) { ctx in
                        contextPill(ctx)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func contextPill(_ ctx: BPContext) -> some View {
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
                    ProgressView().tint(.white)
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
                            startPoint: .leading, endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [VCColors.onSurfaceVariant.opacity(0.3), VCColors.onSurfaceVariant.opacity(0.3)],
                            startPoint: .leading, endPoint: .trailing
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
