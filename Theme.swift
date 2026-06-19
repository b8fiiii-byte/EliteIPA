//
//  Theme.swift
//  نظام الهوية البصرية: الوضع الداكن + تأثيرات الزجاج (Glassmorphism)
//

import SwiftUI

enum Theme {
    // الألوان الأساسية
    static let background = Color(red: 0.04, green: 0.05, blue: 0.09)        // خلفية داكنة عميقة
    static let surface = Color.white.opacity(0.06)                          // سطح زجاجي
    static let stroke = Color.white.opacity(0.12)                           // حدود زجاجية
    static let accent = Color(red: 0.36, green: 0.55, blue: 1.0)           // أزرق فخم
    static let accentGreen = Color(red: 0.20, green: 0.80, blue: 0.45)     // زر التوقيع الأخضر
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.38)

    // تدرّج الخلفية
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.07, blue: 0.13),
            Color(red: 0.03, green: 0.04, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// مُعدِّل يعطي تأثير الزجاج (Glassmorphism) لأي عنصر
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
