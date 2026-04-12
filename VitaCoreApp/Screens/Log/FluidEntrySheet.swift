// FluidEntrySheet.swift
// VitaCore — Fluid intake log entry bottom sheet

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Fluid Type

enum FluidType: String, CaseIterable, Identifiable {
    case water       = "Water"
    case coffee      = "Coffee"
    case tea         = "Tea"
    case juice       = "Juice"
    case electrolyte = "Electrolyte"
    case other       = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .water:       return "drop.fill"
        case .coffee:      return "cup.and.saucer.fill"
        case .tea:         return "leaf.fill"
        case .juice:       return "takeoutbag.and.cup.and.straw.fill"
        case .electrolyte: return "sparkles"
        case .other:       return "drop"
        }
    }

    var color: Color {
        switch self {
        case .water:       return VCColors.tertiary
        case .coffee:      return VCColors.secondary
        case .tea:         return VCColors.safe
        case .juice:       return VCColors.watch
        case .electrolyte: return VCColors.primary
        case .other:       return VCColors.onSurfaceVariant
        }
    }

    var containerColor: Color {
        switch self {
        case .water:       return VCColors.tertiaryContainer
        case .coffee:      return VCColors.secondaryContainer
        case .tea:         return VCColors.safe.opacity(0.15)
        case .juice:       return VCColors.watch.opacity(0.15)
        case .electrolyte: return VCColors.primaryContainer
        case .other:       return VCColors.surfaceLow
        }
    }

    /// Diuretic factor: effective volume = intake * factor
    var diureticFactor: Double? {
        switch self {
        case .coffee: return 0.8
        case .tea:    return 0.8
        default:      return nil
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class FluidEntryViewModel {
    var selectedType: FluidType = .water
    var volumeInput: String = ""
    var selectedTime: Date = Date()

    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var saveError: String? = nil

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    var parsedVolume: Double? {
        guard let v = Double(volumeInput), v > 0 else { return nil }
        return v
    }

    var isValidInput: Bool {
        guard let v = parsedVolume else { return false }
        return v >= 1 && v <= 5000
    }

    var effectiveVolume: Double? {
        guard let v = parsedVolume, let factor = selectedType.diureticFactor else { return nil }
        return v * factor
    }

    var showDiureticWarning: Bool {
        selectedType.diureticFactor != nil && parsedVolume != nil
    }

    func applyPreset(_ ml: Double) {
        volumeInput = Int(ml).description
    }

    func save(onDismiss: @escaping () -> Void) async {
        guard isValidInput, let volume = parsedVolume else { return }
        isSaving = true
        saveError = nil
        let result = await skillBus.logFluidIntake(volumeML: volume, timestamp: selectedTime)
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

struct FluidEntrySheet: View {
    let onDismiss: () -> Void

    @Environment(\.skillBus) private var skillBus
    @State private var viewModel: FluidEntryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                FluidEntrySheetContent(viewModel: vm, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = FluidEntryViewModel(skillBus: skillBus)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(VCColors.background.ignoresSafeArea())
    }
}

// MARK: - Content

private struct FluidEntrySheetContent: View {
    @Bindable var viewModel: FluidEntryViewModel
    let onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool

    private let presets: [Double] = [250, 500, 750, 1000]

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    sheetHeader
                    fluidTypeGrid
                    volumeInputSection
                    presetsRow
                    if viewModel.showDiureticWarning { diureticWarning }
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

            Text("Log Fluid")
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

    // MARK: - Fluid Type Grid

    private var fluidTypeGrid: some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            Text("TYPE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .kerning(1.2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: VCSpacing.sm), GridItem(.flexible(), spacing: VCSpacing.sm)],
                spacing: VCSpacing.sm
            ) {
                ForEach(FluidType.allCases) { fluidType in
                    fluidTypeCard(fluidType)
                }
            }
        }
    }

    private func fluidTypeCard(_ type: FluidType) -> some View {
        let isSelected = viewModel.selectedType == type
        return Button {
            viewModel.selectedType = type
        } label: {
            HStack(spacing: VCSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(type.color)
                    .frame(width: 28, height: 28)

                Text(type.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? VCColors.onSurface : VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VCSpacing.md)
            .padding(.vertical, VCSpacing.md)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: VCRadius.md)
                    .fill(isSelected ? type.containerColor : VCColors.surfaceLow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VCRadius.md)
                    .strokeBorder(
                        isSelected ? type.color.opacity(0.5) : VCColors.outlineVariant,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Volume Input

    private var volumeInputSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.sm) {
                Text("VOLUME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .kerning(1.2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .lastTextBaseline, spacing: VCSpacing.sm) {
                    TextField("—", text: $viewModel.volumeInput)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(VCColors.onSurface)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .frame(maxWidth: .infinity)

                    Text("mL")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .padding(.bottom, 8)
                }
            }
            .padding(VCSpacing.lg)
        }
        .onTapGesture { isInputFocused = true }
    }

    // MARK: - Presets

    private var presetsRow: some View {
        HStack(spacing: VCSpacing.sm) {
            ForEach(presets, id: \.self) { ml in
                Button {
                    viewModel.applyPreset(ml)
                } label: {
                    Text("\(Int(ml))mL")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.md)
                                .fill(VCColors.primaryContainer.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: VCRadius.md)
                                .strokeBorder(VCColors.primary.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Diuretic Warning

    private var diureticWarning: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(VCColors.watch)

            Group {
                if let eff = viewModel.effectiveVolume, let raw = viewModel.parsedVolume {
                    Text(String(format: "Effective volume: 80%% (%.0fmL of %.0fmL)", eff, raw))
                } else {
                    Text("Effective volume: 80% (diuretic effect)")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(VCColors.watch)
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(VCColors.watch.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md)
                        .strokeBorder(VCColors.watch.opacity(0.25), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.showDiureticWarning)
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
