// SpacingTokens.swift
// VitaCoreDesign — Spacing scale tokens

import SwiftUI

// MARK: - VCSpacing

/// Layout spacing constants aligned to an 4-pt base grid.
public enum VCSpacing {
    /// 4 pt — hairline padding, icon micro-gaps.
    public static let xs: CGFloat = 4
    /// 8 pt — tight internal padding.
    public static let sm: CGFloat = 8
    /// 12 pt — comfortable internal padding.
    public static let md: CGFloat = 12
    /// 16 pt — standard section padding.
    public static let lg: CGFloat = 16
    /// 20 pt — generous content spacing.
    public static let xl: CGFloat = 20
    /// 24 pt — card-to-card gaps.
    public static let xxl: CGFloat = 24
    /// 32 pt — section-to-section gaps.
    public static let xxxl: CGFloat = 32
    /// 44 pt — minimum HIG tap target.
    public static let tapTarget: CGFloat = 44
}
