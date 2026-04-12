// NoteEntrySheet.swift
// VitaCore — Symptom/note log entry bottom sheet

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Critical Keyword Detection

private let criticalKeywords: [String] = [
    "chest pain", "chest tightness", "severe headache", "shortness of breath",
    "can't breathe", "cannot breathe", "difficulty breathing", "crushing pain",
    "jaw pain", "arm pain", "left arm", "fainting", "fainted", "passed out",
    "seizure", "stroke", "vision loss", "sudden weakness", "severe dizziness"
]

// MARK: - Mock NER Entity

fileprivate struct NEREntity: Identifiable {
    let id = UUID()
    let text: String
    let type: String   // "symptom", "body_part", "severity", etc.
}

// MARK: - ViewModel

@Observable
@MainActor
final class NoteEntryViewModel {
    var noteText: String = ""
    var selectedTime: Date = Date()

    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var saveError: String? = nil

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    static let maxLength: Int = 500
    static let amberThreshold: Int = 400
    static let redThreshold: Int = 480

    var characterCount: Int { noteText.count }

    var isAtLimit: Bool { characterCount >= Self.maxLength }

    var counterColor: Color {
        if characterCount >= Self.redThreshold   { return VCColors.critical }
        if characterCount >= Self.amberThreshold { return VCColors.watch }
        return VCColors.onSurfaceVariant
    }

    var isValidInput: Bool { characterCount > 0 && characterCount <= Self.maxLength }

    var showCriticalWarning: Bool {
        let lower = noteText.lowercased()
        return criticalKeywords.contains { lower.contains($0) }
    }

    /// Mock NER: extract simple entities from typed text for preview
    fileprivate var detectedEntities: [NEREntity] {
        guard characterCount > 10 else { return [] }
        var entities: [NEREntity] = []

        let symptomWords = ["headache", "fatigue", "nausea", "dizziness", "pain",
                            "tired", "weakness", "swollen", "bloated", "anxious",
                            "fever", "cough", "vomiting", "cramping", "palpitation"]
        let lower = noteText.lowercased()
        for word in symptomWords where lower.contains(word) {
            entities.append(NEREntity(text: word, type: "symptom"))
            if entities.count >= 3 { break }
        }

        return entities
    }

    func enforceLimit() {
        if noteText.count > Self.maxLength {
            noteText = String(noteText.prefix(Self.maxLength))
        }
    }

    func save(onDismiss: @escaping () -> Void) async {
        guard isValidInput else { return }
        isSaving = true
        saveError = nil
        let result = await skillBus.logSymptomNote(text: noteText, timestamp: selectedTime)
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

struct NoteEntrySheet: View {
    let onDismiss: () -> Void

    @Environment(\.skillBus) private var skillBus
    @State private var viewModel: NoteEntryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                NoteEntrySheetContent(viewModel: vm, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = NoteEntryViewModel(skillBus: skillBus)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(VCColors.background.ignoresSafeArea())
    }
}

// MARK: - Content

private struct NoteEntrySheetContent: View {
    @Bindable var viewModel: NoteEntryViewModel
    let onDismiss: () -> Void

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    sheetHeader
                    textEditorSection
                    nerPreviewSection
                    timePickerSection
                    if viewModel.showCriticalWarning { criticalWarningBanner }
                    if let err = viewModel.saveError { errorChip(message: err) }
                    saveButton
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, VCSpacing.xxxl)
                .animation(.easeInOut(duration: 0.2), value: viewModel.showCriticalWarning)
                .animation(.easeInOut(duration: 0.2), value: viewModel.detectedEntities.count)
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

            Text("Log Note")
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

    // MARK: - Text Editor

    private var textEditorSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if viewModel.noteText.isEmpty {
                        Text("How are you feeling? Describe symptoms, mood, or any observations...")
                            .font(.system(size: 15))
                            .foregroundStyle(VCColors.onSurfaceVariant.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $viewModel.noteText)
                        .font(.system(size: 15))
                        .foregroundStyle(VCColors.onSurface)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 144, maxHeight: 288)   // 6–12 lines approx
                        .focused($isEditorFocused)
                        .onChange(of: viewModel.noteText) { _, _ in
                            viewModel.enforceLimit()
                        }
                }

                Divider()
                    .background(VCColors.outlineVariant)
                    .padding(.top, VCSpacing.sm)

                // Character counter
                HStack {
                    Spacer()
                    Text("\(viewModel.characterCount) / \(NoteEntryViewModel.maxLength)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(viewModel.counterColor)
                }
                .padding(.top, VCSpacing.xs)
            }
            .padding(VCSpacing.lg)
        }
        .onTapGesture { isEditorFocused = true }
    }

    // MARK: - NER Preview

    @ViewBuilder
    private var nerPreviewSection: some View {
        let entities = viewModel.detectedEntities
        if !entities.isEmpty {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack(spacing: VCSpacing.xs) {
                    Image(systemName: "brain")
                        .font(.system(size: 11))
                        .foregroundStyle(VCColors.primary)
                    Text("DETECTED")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .kerning(1.2)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VCSpacing.sm) {
                        ForEach(entities) { entity in
                            nerPill(entity)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private func nerPill(_ entity: NEREntity) -> some View {
        HStack(spacing: 4) {
            Text(entity.type)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VCColors.primary.opacity(0.7))
                .textCase(.uppercase)

            Text(entity.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VCColors.primary)
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.xs)
        .background(
            Capsule()
                .fill(VCColors.primaryContainer.opacity(0.7))
        )
        .overlay(
            Capsule()
                .strokeBorder(VCColors.primary.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Critical Warning Banner

    private var criticalWarningBanner: some View {
        HStack(alignment: .top, spacing: VCSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VCColors.critical)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: VCSpacing.xs) {
                Text("Potential critical symptoms detected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VCColors.critical)

                Text("If you are experiencing an emergency, call 999 or 911 immediately. Saving this note will flag it for clinical review.")
                    .font(.system(size: 12))
                    .foregroundStyle(VCColors.critical.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VCSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(VCColors.critical.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md)
                        .strokeBorder(VCColors.critical.opacity(0.3), lineWidth: 1.5)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
