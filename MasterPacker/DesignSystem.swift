import SwiftUI
import UIKit

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

    /// Card/row surface — solid white in light mode, a dark elevated
    /// navy-gray in dark mode. Used by `floatingCard()` and any
    /// `.listRowBackground` that needs to sit crisply on `screenGradient`
    /// rather than blend into it (the whole point of these surfaces is
    /// contrast against the gradient, so this must track appearance).
    static let cardSurface = Color.adaptive(light: 0xFFFFFF, dark: 0x1E2433)

    // MARK: - Layout

    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 12

    // MARK: - Gradients

    /// The soft gradient wash used behind full-screen List/Form content
    /// instead of plain white — approved visual direction "Option A".
    /// Adapts to a dark navy-to-near-black wash in dark mode rather than
    /// staying fixed-light, since a fixed light background combined with
    /// system text colors flipping to white in dark mode made text
    /// unreadable.
    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptive(light: 0xEAF1FD, dark: 0x0E1526),
                Color.adaptive(light: 0xF7F4EC, dark: 0x171E30),
                Color.adaptive(light: 0xF4EFE2, dark: 0x1E1B15),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Diagonal brand gradient used for icon badges and header cards.
    /// Deliberately fixed (not appearance-adaptive) — it's always paired
    /// with white text/icons on top, so it reads correctly in both modes
    /// without needing to change.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [brand, navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
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

    /// An appearance-adaptive color, switching between a light and dark hex
    /// value based on the system's current light/dark mode — there's no
    /// SwiftUI-native way to do this for a hand-picked hex color (only for
    /// Asset Catalog color sets), so this bridges through `UIColor`'s
    /// dynamic-provider initializer instead.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
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

/// A solid floating card (white in light mode, dark elevated surface in
/// dark mode) with a soft brand-tinted shadow — used for list rows sitting
/// on `AppTheme.screenGradient`. Prefer this over `cardStyle()` when the
/// row needs to read crisply against the gradient background rather than
/// blend into it.
private struct FloatingCard: ViewModifier {
    var radius: CGFloat = AppTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: AppTheme.navy.opacity(0.12), radius: 14, y: 8)
    }
}

extension View {
    func floatingCard(radius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(FloatingCard(radius: radius))
    }
}

/// A colored rounded-square badge showing a symbol — e.g. the travel-method
/// icon on a trip row.
struct IconBadge: View {
    let systemImage: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: AppTheme.brand.opacity(0.35), radius: 8, y: 4)
    }
}

/// A small circular percent-complete indicator (e.g. packing progress on a
/// trip row). Use `ProgressBar` for a full-width bar instead.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 4
    var diameter: CGFloat = 34
    var color: Color = AppTheme.sage

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A full-width progress bar with a custom track/fill — used on the trip
/// detail header card.
struct ProgressBar: View {
    let progress: Double
    var trackColor: Color = .white.opacity(0.22)
    var fillColor: Color = AppTheme.sage.opacity(0.85)
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(fillColor)
                    .frame(width: geo.size.width * max(0.02, min(1, progress)))
            }
        }
        .frame(height: height)
    }
}
