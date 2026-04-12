import SwiftUI
import VitaCoreDesign

// MARK: - Export Period

private enum ExportPeriod: String, CaseIterable, Identifiable {
    case sevenDays  = "Last 7 Days"
    case thirtyDays = "Last 30 Days"
    case ninetyDays = "Last 90 Days"
    case oneYear    = "Last Year"
    case allTime    = "All Time"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .sevenDays:  return "7d"
        case .thirtyDays: return "30d"
        case .ninetyDays: return "90d"
        case .oneYear:    return "1y"
        case .allTime:    return "All"
        }
    }
}

// MARK: - Appointment Type

private enum AppointmentType: String, CaseIterable, Identifiable {
    case annualPhysical  = "Annual Physical"
    case endocrinology   = "Endocrinology"
    case cardiology      = "Cardiology"
    case diabetesFollowUp = "Diabetes Follow-up"
    case sleepStudy      = "Sleep Study"
    case mentalHealth    = "Mental Health"
    case nutrition       = "Nutrition"
    case other           = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .annualPhysical:  return "figure.stand"
        case .endocrinology:   return "waveform.path.ecg"
        case .cardiology:      return "heart.fill"
        case .diabetesFollowUp: return "drop.fill"
        case .sleepStudy:      return "moon.fill"
        case .mentalHealth:    return "brain.head.profile"
        case .nutrition:       return "fork.knife"
        case .other:           return "stethoscope"
        }
    }
}

// MARK: - Main View

struct ExportSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showPDFPeriodSheet: Bool = false
    @State private var showClinicianSheet: Bool = false
    @State private var selectedPDFPeriod: ExportPeriod = .thirtyDays
    @State private var selectedAppointmentType: AppointmentType = .annualPhysical
    @State private var isExportingPDF: Bool = false
    @State private var isExportingJSON: Bool = false
    @State private var isCreatingSnapshot: Bool = false

    // Mock JSON-LD stats
    private let jsonRecordCount: Int = 4_821
    private let jsonEstimatedSize: String = "~18 MB"

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    header

                    sectionLabel("EXPORT FORMATS")

                    // PDF Health Summary
                    pdfExportCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // JSON-LD Graph Export
                    jsonLDExportCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Clinician Snapshot
                    clinicianSnapshotCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Footer note
                    footerNote
                        .padding(.horizontal, VCSpacing.xxl)

                    Spacer().frame(height: 40)
                }
                .padding(.top, VCSpacing.xxl)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) { backButton }
        // PDF period picker sheet
        .sheet(isPresented: $showPDFPeriodSheet) {
            PDFPeriodSheet(
                selectedPeriod: $selectedPDFPeriod,
                onExport: {
                    showPDFPeriodSheet = false
                    Task {
                        isExportingPDF = true
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isExportingPDF = false
                    }
                },
                onCancel: { showPDFPeriodSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Clinician appointment type sheet
        .sheet(isPresented: $showClinicianSheet) {
            ClinicianSheet(
                selectedType: $selectedAppointmentType,
                onCreate: {
                    showClinicianSheet = false
                    Task {
                        isCreatingSnapshot = true
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isCreatingSnapshot = false
                    }
                },
                onCancel: { showClinicianSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer().frame(width: 44 + VCSpacing.lg)
            Text("Export")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, 60)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            ZStack {
                Circle()
                    .fill(VCColors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VCColors.primary)
            }
        }
        .padding(.leading, VCSpacing.lg)
        .padding(.top, 56)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(VCColors.outline)
                .padding(.leading, VCSpacing.md)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, VCSpacing.xs)
    }

    // MARK: - PDF Export Card

    private var pdfExportCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VCColors.primary.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(VCColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PDF Health Summary")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("Comprehensive health report for your records or doctor")
                            .font(.system(size: 13))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    showPDFPeriodSheet = true
                } label: {
                    HStack(spacing: 8) {
                        if isExportingPDF {
                            ProgressView().scaleEffect(0.85).tint(VCColors.primary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isExportingPDF ? "Exporting..." : "Export PDF")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(VCColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.sm)
                            .strokeBorder(VCColors.primary.opacity(0.5), lineWidth: 1.5)
                    )
                }
                .disabled(isExportingPDF)
            }
        }
    }

    // MARK: - JSON-LD Export Card

    private var jsonLDExportCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VCColors.tertiary.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "curlybraces")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(VCColors.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("JSON-LD Graph Export")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("Machine-readable export following schema.org/MedicalObservation and FHIR R4 vocabulary")
                            .font(.system(size: 13))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Stats row
                HStack(spacing: VCSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(jsonRecordCount.formatted())")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VCColors.tertiary)
                        Text("Records")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(VCColors.outline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(jsonEstimatedSize)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VCColors.tertiary)
                        Text("Est. Size")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(VCColors.outline)
                    }
                    Spacer()
                }
                .padding(.vertical, VCSpacing.xs)

                Button {
                    Task {
                        isExportingJSON = true
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isExportingJSON = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isExportingJSON {
                            ProgressView().scaleEffect(0.85).tint(VCColors.tertiary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isExportingJSON ? "Exporting..." : "Export JSON-LD")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(VCColors.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.sm)
                            .strokeBorder(VCColors.tertiary.opacity(0.5), lineWidth: 1.5)
                    )
                }
                .disabled(isExportingJSON)
            }
        }
    }

    // MARK: - Clinician Snapshot Card

    private var clinicianSnapshotCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VCColors.secondary.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "stethoscope")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(VCColors.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clinician Snapshot")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("Targeted 1–2 page summary for a specific appointment type")
                            .font(.system(size: 13))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    showClinicianSheet = true
                } label: {
                    HStack(spacing: 8) {
                        if isCreatingSnapshot {
                            ProgressView().scaleEffect(0.85).tint(VCColors.secondary)
                        } else {
                            Image(systemName: "plus.square.fill.on.square.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isCreatingSnapshot ? "Creating..." : "Create Snapshot")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(VCColors.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.sm)
                            .strokeBorder(VCColors.secondary.opacity(0.5), lineWidth: 1.5)
                    )
                }
                .disabled(isCreatingSnapshot)
            }
        }
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        VStack(spacing: VCSpacing.xs) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(VCColors.outline)
                Text("All exports use the iOS Share Sheet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
            Text("VitaCore never auto-exports or transmits your data without your explicit action.")
                .font(.system(size: 11))
                .foregroundStyle(VCColors.outline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VCSpacing.sm)
    }
}

// MARK: - PDF Period Sheet

private struct PDFPeriodSheet: View {
    @Binding var selectedPeriod: ExportPeriod
    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, VCSpacing.lg)

            Text("Select Time Period")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
                .padding(.bottom, VCSpacing.lg)

            VStack(spacing: 0) {
                ForEach(ExportPeriod.allCases) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        HStack {
                            Text(period.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(VCColors.onSurface)
                            Spacer()
                            if selectedPeriod == period {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(VCColors.primary)
                            }
                        }
                        .padding(.horizontal, VCSpacing.xxl)
                        .frame(height: 52)
                    }
                    if period != ExportPeriod.allCases.last {
                        Divider()
                            .padding(.horizontal, VCSpacing.xxl)
                    }
                }
            }
            .background(VCColors.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
            .padding(.horizontal, VCSpacing.lg)

            Spacer().frame(height: VCSpacing.xl)

            Button {
                onExport()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Export PDF for \(selectedPeriod.rawValue)")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(VCColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
            }
            .padding(.horizontal, VCSpacing.lg)

            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, VCSpacing.lg)

            Spacer().frame(height: VCSpacing.lg)
        }
        .background(VCColors.background)
    }
}

// MARK: - Clinician Sheet

private struct ClinicianSheet: View {
    @Binding var selectedType: AppointmentType
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, VCSpacing.lg)

            Text("Appointment Type")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
            Text("Select the visit type for your clinician snapshot")
                .font(.system(size: 13))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .padding(.top, 4)
                .padding(.bottom, VCSpacing.lg)

            ScrollView {
                VStack(spacing: VCSpacing.sm) {
                    ForEach(AppointmentType.allCases) { appt in
                        Button {
                            selectedType = appt
                        } label: {
                            HStack(spacing: VCSpacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(VCColors.secondary.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: appt.iconName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(VCColors.secondary)
                                }

                                Text(appt.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(VCColors.onSurface)

                                Spacer()

                                if selectedType == appt {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(VCColors.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(VCColors.outline)
                                }
                            }
                            .padding(.horizontal, VCSpacing.lg)
                            .frame(height: 52)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, VCSpacing.md)
            }

            Divider().padding(.vertical, VCSpacing.md)

            Button {
                onCreate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Create \(selectedType.rawValue) Snapshot")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(VCColors.secondary)
                .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
            }
            .padding(.horizontal, VCSpacing.lg)

            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .frame(height: 48)
                .frame(maxWidth: .infinity)

            Spacer().frame(height: VCSpacing.sm)
        }
        .background(VCColors.background)
    }
}
