import SwiftUI

/// Shared design tokens for MasterPacker, pulled from the app icon (a blue
/// suitcase scene with a navy case, cream label, and olive toiletry bag).
///
/// New screens should reach for these instead of hardcoding colors, so the
/// whole app stays visually consistent as features are added. The tint
/// color and font design are already applied app-wide from the root
/// `ContentView`, so most new views get the brand look for free — reach for
/// `AppTheme` explicitly only when you need a specific brand color (e.g.
/// the "packed" success color) or a card-style container.
enum AppTheme {
    // MARK: - Palette

    /// Primary brand color — also set as the AccentColor asset, so it's
    /// already the default tint for buttons, links, and selected states
    /// everywhere without needing to apply it manually.
    static let brand = Color(hex: 0x2F6FE0)

    /// Deep navy — the suitcase color in the icon. Good for high-contrast
    /// text or dark surfaces (e.g. the splash screen gradient).
    static let navy = Color(hex: 0x16233E)

    /// Warm cream — the label background in the icon. Good for text on
    /// dark/brand-colored surfaces.
    static let cream = Color(hex: 0xF4EFE2)

    /// Olive green — the toiletry bag in the icon. Used for "packed"/
    /// success states instead of plain system green, so they read as
    /// on-brand rather than generic.
    static let sage = Color(hex: 0x6E7A4E)

    // MARK: - Layout

    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 12
}

extension Color {
    /// Convenience initializer for the app's hex-defined brand colors.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// A consistent card container — grouped content on a rounded, adaptive
/// (light/dark aware) surface. Prefer this over one-off background/padding/
/// cornerRadius combinations when a screen needs a custom card outside of a
/// List/Form.
private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}
