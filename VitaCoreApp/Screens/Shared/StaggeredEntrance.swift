// StaggeredEntrance.swift
// VitaCore — Reusable staggered entrance modifier for list/section fade-in.

import SwiftUI
import VitaCoreDesign

public extension View {
    /// Applies a staggered entrance animation (fade + subtle upward slide).
    ///
    /// Usage:
    /// ```swift
    /// @State private var visible = false
    /// ...
    /// sectionA.staggeredEntrance(index: 0, visible: visible)
    /// sectionB.staggeredEntrance(index: 1, visible: visible)
    /// sectionC.staggeredEntrance(index: 2, visible: visible)
    /// ```
    ///
    /// Trigger `visible = true` in `.task` after content loads.
    func staggeredEntrance(index: Int, visible: Bool, distance: CGFloat = 16) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : distance)
            .animation(
                VCAnimation.cardEntrance.delay(VCAnimation.staggerDelay(index: index, step: 0.07)),
                value: visible
            )
    }
}
