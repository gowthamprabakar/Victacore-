// BackgroundMesh.swift
// VitaCoreDesign — Animated ethereal background with organic blob shapes

import SwiftUI

// MARK: - BackgroundMesh

/// A full-bleed animated background composed of four radial-gradient blobs
/// that drift slowly across the canvas, creating the Ethereal Light atmosphere.
///
/// Place this behind all content:
/// ```swift
/// ZStack {
///     BackgroundMesh()
///     // ... content
/// }
/// ```
public struct BackgroundMesh: View {

    // -------------------------------------------------------------------------
    // MARK: Blob descriptors
    // -------------------------------------------------------------------------

    struct Blob {
        var color: Color
        /// Position as a fraction of the canvas (0..1 on x and y).
        var startPosition: UnitPoint
        var endPosition: UnitPoint
        var size: CGFloat
        var duration: Double
    }

    /// Four organic blobs that produce a subtle but premium ethereal atmosphere.
    /// Positions are UnitPoints so the blobs stay inside the canvas on any device size.
    private let blobs: [Blob] = [
        Blob(
            color: VCColors.primaryContainer.opacity(0.65),
            startPosition: UnitPoint(x: 0.1, y: 0.1),
            endPosition:   UnitPoint(x: 0.4, y: 0.3),
            size: 460,
            duration: 22
        ),
        Blob(
            color: VCColors.secondaryContainer.opacity(0.55),
            startPosition: UnitPoint(x: 0.85, y: 0.25),
            endPosition:   UnitPoint(x: 0.60, y: 0.05),
            size: 380,
            duration: 26
        ),
        Blob(
            color: VCColors.tertiaryContainer.opacity(0.40),
            startPosition: UnitPoint(x: 0.25, y: 0.85),
            endPosition:   UnitPoint(x: 0.55, y: 0.65),
            size: 420,
            duration: 30
        ),
        Blob(
            color: VCColors.primaryContainer.opacity(0.35),
            startPosition: UnitPoint(x: 0.90, y: 0.80),
            endPosition:   UnitPoint(x: 0.70, y: 0.95),
            size: 340,
            duration: 34
        )
    ]

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Subtle vertical gradient background
                LinearGradient(
                    colors: [
                        VCColors.background,
                        VCColors.surfaceLow.opacity(0.6),
                        VCColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(0..<blobs.count, id: \.self) { i in
                    BlobView(blob: blobs[i], canvasSize: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - BlobView

private struct BlobView: View {
    let blob: BackgroundMesh.Blob
    let canvasSize: CGSize
    @State private var phase: Bool = false

    var body: some View {
        let startX = canvasSize.width  * blob.startPosition.x
        let startY = canvasSize.height * blob.startPosition.y
        let endX   = canvasSize.width  * blob.endPosition.x
        let endY   = canvasSize.height * blob.endPosition.y

        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        blob.color,
                        blob.color.opacity(0.5),
                        blob.color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: blob.size / 2
                )
            )
            .frame(width: blob.size, height: blob.size)
            .blur(radius: 80)
            .position(
                x: phase ? endX : startX,
                y: phase ? endY : startY
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: blob.duration)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = true
                }
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("BackgroundMesh") {
    ZStack {
        BackgroundMesh()
        VStack(spacing: VCSpacing.xxl) {
            Text("Ethereal Light")
                .vcFont(.display)
                .foregroundStyle(VCColors.onSurface)
            Text("VitaCore Design System")
                .vcFont(.headline)
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
    }
}
#endif
