// LoadingShimmer.swift
// VitaCoreApp — Animated shimmer placeholder for loading states.
//
// Drop `LoadingShimmer()` anywhere a content card would appear while
// data is being fetched or the model is warming up. Matches the app's
// Deep Space Bioluminescence surface palette via VCColors.

import SwiftUI
import VitaCoreDesign

/// A shimmer loading placeholder that can be used anywhere in the app.
public struct LoadingShimmer: View {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = -1.0

    public init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        VCColors.surfaceLow,
                        VCColors.surfaceHigh.opacity(0.8),
                        VCColors.surfaceLow
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 300)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        LoadingShimmer(cornerRadius: 22)
            .frame(height: 100)
        LoadingShimmer(cornerRadius: 12)
            .frame(height: 60)
        HStack {
            LoadingShimmer(cornerRadius: 18)
                .frame(height: 80)
            LoadingShimmer(cornerRadius: 18)
                .frame(height: 80)
        }
    }
    .padding()
    .background(VCColors.background)
}
#endif
