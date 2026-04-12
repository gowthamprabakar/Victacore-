// WeightEntrySheet.swift
// VitaCore — Weight log entry bottom sheet

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Weight Unit (renamed to avoid conflict with onboarding's local WeightUnit)

enum LogWeightUnit: String, CaseIterable {
    case kg      = "kg"
    case lb      = "lb"
    case stoneLb = "st+lb"
}

// MARK: - ViewModel

@Observable
@MainActor
final class WeightEntryViewModel {
    var primaryInput: String = ""    // kg or lb or stone
    var lbInput: String = ""         // only used for stone+lb mode
    var selectedUnit: LogWeightUnit = .kg
    var selectedTime: Date = Date()

    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var saveError: String? = nil

    // Mock 7-day trend (placeholder until GraphStore provides real data)
    let trendData: [Double] = [78.2, 78.0, 78.1, 77.9, 78.0, 77.8, 77.9]

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    // MARK: - Conversions

    var parsedPrimary: Double? {
        guard let v = Double(primaryInput), v > 0 else { return nil }
        return v
    }

    var parsedLb: Double? {
        guard let v = Double(lbInput) else { return nil }
        return v
    }

    /// Returns kg value regardless of selected unit
    var valueInKg: Double? {
        guard let p = parsedPrimary else { return nil }
        switch selectedUnit {
        case .kg:      return p
        case .lb:      return p * 0.4536
        case .stoneLb:
            let stone = p
            let lb = parsedLb ?? 0.0
            return ((stone * 14.0) + lb) * 0.4536
        }
    }

    var isValidInput: Bool {
        guard let kg = valueInKg else { return false }
        return kg >= 1 && kg <= 700  // sensible physiological range
    }

    var displayKg: String? {
        guard let kg = valueInKg else { return nil }
        return String(format: "%.1f kg", kg)
    }

    var trendLabel: String {
        guard trendData.count >= 2 else { return "" }
        let diff = trendData.last! - trendData.first!
        let sign = diff < 0 ? "↓" : "↑"
        return String(format: "%@ %.1f kg from last week", sign, abs(diff))
    }

    func save(onDismiss: @escaping () -> Void) async {
        guard isValidInput, let kg = valueInKg else { return }
        isSaving = true
        saveError = nil
        let result = await skillBus.logWeight(valueKg: kg, timestamp: selectedTime)
        isSaving = false
        if result.success {
            saveSuccess = true
            // Keep sheet open briefly to show trend chart, then dismiss
            try? await Task.sleep(nanoseconds: 600_000_000)
            onDismiss()
        } else {
            saveError = result.message ?? "Failed to save. Please try again."
        }
    }
}

// MARK: - View

struct WeightEntrySheet: View {
    let onDismiss: () -> Void

    @Environment(\.skillBus) private var skillBus
    @State private var viewModel: WeightEntryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                WeightEntrySheetContent(viewModel: vm, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = WeightEntryViewModel(skillBus: skillBus)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(VCColors.background.ignoresSafeArea())
    }
}

// MARK: - Content

private struct WeightEntrySheetContent: View {
    @Bindable var viewModel: WeightEntryViewModel
    let onDismiss: () -> Void

    @FocusState private var focusedField: WeightField?

    enum WeightField { case primary, lb }

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    sheetHeader
                    weightInputSection
                    unitToggleSection
                    if viewModel.selectedUnit != .kg, let display = viewModel.displayKg {
                        conversionHint(display)
                    }
                    timePickerSection
                    if viewModel.saveSuccess { trendSection }
                    if let err = viewModel.saveError { errorChip(message: err) }
                    saveButton
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, VCSpacing.xxxl)
                .animation(.easeInOut(duration: 0.3), value: viewModel.saveSuccess)
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

            Text("Log Weight")
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

    // MARK: - Weight Input

    private var weightInputSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.sm) {
                Text("WEIGHT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .kerning(1.2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.selectedUnit == .stoneLb {
                    stoneLbInput
                } else {
                    standardInput
                }
            }
            .padding(VCSpacing.lg)
        }
    }

    private var standardInput: some View {
        HStack(alignment: .lastTextBaseline, spacing: VCSpacing.sm) {
            TextField("—", text: $viewModel.primaryInput)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .primary)
                .frame(maxWidth: .infinity)

            Text(viewModel.selectedUnit.rawValue)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .padding(.bottom, 8)
        }
    }

    private var stoneLbInput: some View {
        HStack(alignment: .lastTextBaseline, spacing: VCSpacing.lg) {
            VStack(alignment: .center) {
                TextField("—", text: $viewModel.primaryInput)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(VCColors.onSurface)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .primary)

                Text("st")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)

            Text("+")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .padding(.bottom, 20)

            VStack(alignment: .center) {
                TextField("0", text: $viewModel.lbInput)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(VCColors.onSurface)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .lb)

                Text("lb")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Unit Toggle

    private var unitToggleSection: some View {
        Picker("Unit", selection: $viewModel.selectedUnit) {
            ForEach(LogWeightUnit.allCases, id: \.self) { unit in
                Text(unit.rawValue).tag(unit)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 44)
        .onChange(of: viewModel.selectedUnit) { _, _ in
            viewModel.primaryInput = ""
            viewModel.lbInput = ""
        }
    }

    // MARK: - Conversion Hint

    private func conversionHint(_ display: String) -> some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(VCColors.onSurfaceVariant)
            Text(display)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

    // MARK: - Trend Chart (shown after successful save)

    private var trendSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("7-DAY TREND")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .kerning(1.2)

                // Inline area chart using Canvas
                WeightMiniChart(data: viewModel.trendData)
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)

                // Trend pill
                HStack(spacing: VCSpacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VCColors.safe)

                    Text(viewModel.trendLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VCColors.safe)
                }
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, VCSpacing.xs)
                .background(
                    Capsule().fill(VCColors.safe.opacity(0.1))
                )
            }
            .padding(VCSpacing.lg)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

// MARK: - Mini Weight Chart

private struct WeightMiniChart: View {
    let data: [Double]

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }

            let minVal = data.min()! - 0.5
            let maxVal = data.max()! + 0.5
            let range = maxVal - minVal
            let stepX = size.width / CGFloat(data.count - 1)

            func point(at index: Int) -> CGPoint {
                let x = CGFloat(index) * stepX
                let normalized = (data[index] - minVal) / range
                let y = size.height - (CGFloat(normalized) * size.height)
                return CGPoint(x: x, y: y)
            }

            // Area fill
            var areaPath = Path()
            areaPath.move(to: CGPoint(x: 0, y: size.height))
            areaPath.addLine(to: point(at: 0))
            for i in 1..<data.count {
                areaPath.addLine(to: point(at: i))
            }
            areaPath.addLine(to: CGPoint(x: size.width, y: size.height))
            areaPath.closeSubpath()

            context.fill(
                areaPath,
                with: .linearGradient(
                    Gradient(colors: [
                        VCColors.primary.opacity(0.25),
                        VCColors.primary.opacity(0.02)
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            // Line
            var linePath = Path()
            linePath.move(to: point(at: 0))
            for i in 1..<data.count {
                linePath.addLine(to: point(at: i))
            }

            context.stroke(
                linePath,
                with: .color(VCColors.primary),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Dot at last point
            let last = point(at: data.count - 1)
            let dotRect = CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dotRect), with: .color(VCColors.primary))
            context.fill(
                Path(ellipseIn: CGRect(x: last.x - 2, y: last.y - 2, width: 4, height: 4)),
                with: .color(.white)
            )
        }
    }
}
