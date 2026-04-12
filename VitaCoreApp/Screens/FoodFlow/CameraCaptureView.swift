// CameraCaptureView.swift
// VitaCore – Food Photo Analysis Pipeline – Stage 1
// Full-screen camera chrome. Simulator/preview uses a dark placeholder.
// On device this wraps AVCaptureSession via a UIViewControllerRepresentable
// (to be wired in a future sprint). For now the shutter creates a mock image.

import SwiftUI
import UIKit
import VitaCoreDesign

// MARK: - Main View

struct CameraCaptureView: View {

    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    // MARK: Local state
    @State private var isFlashOn: Bool = false
    @State private var showFocusHint: Bool = true
    @State private var focusHintOpacity: Double = 1.0
    @State private var shutterPressed: Bool = false

    private let shutterSize: CGFloat = 72
    private let controlButtonSize: CGFloat = 44

    var body: some View {
        ZStack {
            // ── Camera feed (black background + placeholder for sim) ──
            cameraBackground

            // ── Framing guide overlay ──
            framingGuide

            // ── Top gradient + controls ──
            VStack {
                topBar
                Spacer()
                bottomBar
            }

            // ── Focus hint (fades after 3 seconds) ──
            if showFocusHint {
                focusTapHint
                    .opacity(focusHintOpacity)
                    .animation(.easeInOut(duration: 0.4), value: focusHintOpacity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { scheduleFocusHintDismiss() }
    }

    // MARK: - Camera Background

    private var cameraBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Placeholder: subtle vignette + food icon
            VStack(spacing: VCSpacing.lg) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.white.opacity(0.15))

                Text("Camera Preview")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.10))
            }
        }
    }

    // MARK: - Framing Guide

    private var framingGuide: some View {
        GeometryReader { geo in
            let guideW = geo.size.width * 0.78
            let guideH = guideW * 0.75
            let cornerLen: CGFloat = 22
            let cornerRadius: CGFloat = VCRadius.lg

            ZStack {
                // Dimming mask outside the guide rectangle
                Rectangle()
                    .fill(.black.opacity(0.35))
                    .mask(
                        Rectangle()
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .frame(width: guideW, height: guideH)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
                    .ignoresSafeArea()

                // Corner brackets
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [VCColors.primaryContainer.opacity(0.9), VCColors.tertiaryContainer.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: guideW, height: guideH)

                // Corner accent marks – top-left
                CornerMark(position: .topLeading, length: cornerLen, radius: cornerRadius)
                    .frame(width: guideW, height: guideH)

                CornerMark(position: .topTrailing, length: cornerLen, radius: cornerRadius)
                    .frame(width: guideW, height: guideH)

                CornerMark(position: .bottomLeading, length: cornerLen, radius: cornerRadius)
                    .frame(width: guideW, height: guideH)

                CornerMark(position: .bottomTrailing, length: cornerLen, radius: cornerRadius)
                    .frame(width: guideW, height: guideH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Gradient scrim
            LinearGradient(
                colors: [.black.opacity(0.65), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)

            HStack(alignment: .center) {
                // Cancel
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(minWidth: controlButtonSize, minHeight: controlButtonSize)
                }
                .padding(.leading, VCSpacing.lg)

                Spacer()

                // Title
                Text("Capture your meal")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                // Flash toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFlashOn.toggle()
                    }
                } label: {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isFlashOn ? VCColors.watch : .white)
                        .frame(width: controlButtonSize, height: controlButtonSize)
                }
                .padding(.trailing, VCSpacing.lg)
            }
            .padding(.top, 54) // account for status bar area
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            // Gradient scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            HStack(alignment: .center, spacing: 0) {
                // Gallery button
                Button {
                    // Photo library picker – future sprint
                } label: {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: controlButtonSize + 10, height: controlButtonSize + 10)
                }
                .padding(.leading, VCSpacing.xxl)

                Spacer()

                // Shutter button
                shutterButton

                Spacer()

                // Switch camera
                Button {
                    // Front/back toggle – future sprint
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: controlButtonSize + 10, height: controlButtonSize + 10)
                }
                .padding(.trailing, VCSpacing.xxl)
            }
            .padding(.bottom, 52) // tab-bar safe area
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button {
            fireShutter()
        } label: {
            ZStack {
                // Outer gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [VCColors.primaryContainer, VCColors.tertiaryContainer],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: shutterSize + 12, height: shutterSize + 12)

                // White disc
                Circle()
                    .fill(.white)
                    .frame(width: shutterSize, height: shutterSize)
                    .shadow(color: .white.opacity(0.3), radius: 8)

                // Inner gradient highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                VCColors.primaryContainer.opacity(0.35),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: shutterSize * 0.6
                        )
                    )
                    .frame(width: shutterSize, height: shutterSize)
            }
            .scaleEffect(shutterPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: shutterPressed)
        }
        .frame(width: shutterSize + 20, height: shutterSize + 20)
        ._onButtonGesture(
            pressing: { pressing in
                withAnimation { shutterPressed = pressing }
            },
            perform: {}
        )
    }

    // MARK: - Focus Hint

    private var focusTapHint: some View {
        VStack(spacing: VCSpacing.sm) {
            Image(systemName: "viewfinder")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.7))

            Text("Position food in frame, then tap to capture")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, VCSpacing.xl)
        .padding(.vertical, VCSpacing.md)
        .background(.ultraThinMaterial, in: Capsule())
        // Vertically centred, slightly above the mid-point
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func scheduleFocusHintDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.5)) {
                focusHintOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showFocusHint = false
            }
        }
    }

    private func fireShutter() {
        // Mock: produce a solid-colour UIImage to drive the pipeline.
        // On device this will be replaced by the AVFoundation capture callback.
        let size = CGSize(width: 640, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        let mockImage = renderer.image { ctx in
            UIColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40),
                .foregroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 0.6)
            ]
            ("🍛" as NSString).draw(
                at: CGPoint(x: size.width / 2 - 25, y: size.height / 2 - 30),
                withAttributes: attrs
            )
        }

        onImageCaptured(mockImage)
    }
}

// MARK: - Corner Mark Helper

private enum CornerPosition {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

private struct CornerMark: View {
    let position: CornerPosition
    let length: CGFloat
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                let t: CGFloat = 3 // stroke width

                switch position {
                case .topLeading:
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: 0, y: radius))
                    path.addArc(center: CGPoint(x: radius, y: radius),
                                radius: radius,
                                startAngle: .degrees(180),
                                endAngle: .degrees(270),
                                clockwise: false)
                    path.addLine(to: CGPoint(x: length, y: 0))

                case .topTrailing:
                    path.move(to: CGPoint(x: w - length, y: 0))
                    path.addLine(to: CGPoint(x: w - radius, y: 0))
                    path.addArc(center: CGPoint(x: w - radius, y: radius),
                                radius: radius,
                                startAngle: .degrees(270),
                                endAngle: .degrees(0),
                                clockwise: false)
                    path.addLine(to: CGPoint(x: w, y: length))

                case .bottomLeading:
                    path.move(to: CGPoint(x: 0, y: h - length))
                    path.addLine(to: CGPoint(x: 0, y: h - radius))
                    path.addArc(center: CGPoint(x: radius, y: h - radius),
                                radius: radius,
                                startAngle: .degrees(180),
                                endAngle: .degrees(90),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: length, y: h))

                case .bottomTrailing:
                    path.move(to: CGPoint(x: w - length, y: h))
                    path.addLine(to: CGPoint(x: w - radius, y: h))
                    path.addArc(center: CGPoint(x: w - radius, y: h - radius),
                                radius: radius,
                                startAngle: .degrees(90),
                                endAngle: .degrees(0),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: w, y: h - length))
                }
            }
            .stroke(Color.white, lineWidth: 3)
        }
    }
}

// MARK: - _onButtonGesture backfill

// SwiftUI's public API does not expose pressing callbacks on Button directly.
// We use a simultaneous DragGesture of zero minimum distance as a proxy.
extension View {
    func _onButtonGesture(pressing: @escaping (Bool) -> Void, perform: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing(true) }
                .onEnded { _ in pressing(false); perform() }
        )
    }
}
