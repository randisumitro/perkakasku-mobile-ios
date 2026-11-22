import SwiftUI
import UIKit

// MARK: - Appearance Mode

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Alabaster (Light)"
        case .dark: return "Espresso (Dark)"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Design Tokens (Aligned with Perkakasku Website: Alabaster, Espresso & Signal Orange)

enum PKColors {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Surfaces & Canvas
    static let background = adaptive(
        light: UIColor(hex: 0xF6F4EF),
        dark: UIColor(hex: 0x121110)
    )
    static let backgroundSecondary = adaptive(
        light: UIColor(hex: 0xEDEAE2),
        dark: UIColor(hex: 0x1B1917)
    )
    static let backgroundTertiary = adaptive(
        light: UIColor(hex: 0xE4DFD5),
        dark: UIColor(hex: 0x25221F)
    )
    static let backgroundInset = adaptive(
        light: UIColor(hex: 0xF0EDE6),
        dark: UIColor(hex: 0x171513)
    )
    static let surface = adaptive(
        light: UIColor(hex: 0xFFFFFF),
        dark: UIColor(hex: 0x1C1A17)
    )
    static let surfaceElevated = adaptive(
        light: UIColor(hex: 0xFAF9F6),
        dark: UIColor(hex: 0x24211D)
    )
    static let surfaceHover = adaptive(
        light: UIColor(hex: 0xF3F0E8),
        dark: UIColor(hex: 0x2B2722)
    )

    // Contrast Espresso Stage (Matches .pk-banner-espresso & .pk-iso-stage)
    static let espressoSurface = Color(uiColor: UIColor(hex: 0x161412))
    static let espressoElevated = Color(uiColor: UIColor(hex: 0x211E1B))
    static let espressoText = Color(uiColor: UIColor(hex: 0xF6F4EF))
    static let espressoMuted = Color(uiColor: UIColor(hex: 0xC5BEB4))
    static let espressoBorder = Color(uiColor: UIColor(hex: 0xF6F4EF, alpha: 0.14))

    // Typography Colors
    static let textPrimary = adaptive(
        light: UIColor(hex: 0x181614),
        dark: UIColor(hex: 0xF6F4EF)
    )
    static let textSecondary = adaptive(
        light: UIColor(hex: 0x524D47),
        dark: UIColor(hex: 0xCBC4BA)
    )
    static let textMuted = adaptive(
        light: UIColor(hex: 0x666057),
        dark: UIColor(hex: 0x9E968B)
    )

    // Brand & Signal Accents
    static let brand = adaptive(
        light: UIColor(hex: 0xD94608),
        dark: UIColor(hex: 0xFB7128)
    )
    static let brandVivid = Color(uiColor: UIColor(hex: 0xF95B12))
    static let brandSoft = adaptive(
        light: UIColor(hex: 0xF95B12, alpha: 0.11),
        dark: UIColor(hex: 0xFB7128, alpha: 0.16)
    )
    static let brandBorder = adaptive(
        light: UIColor(hex: 0xD94608, alpha: 0.28),
        dark: UIColor(hex: 0xFB7128, alpha: 0.34)
    )

    // Ink CTA (High-contrast primary architectural button)
    static let inkCTA = adaptive(
        light: UIColor(hex: 0x181614),
        dark: UIColor(hex: 0xF6F4EF)
    )
    static let inkCTAText = adaptive(
        light: UIColor(hex: 0xFFFFFF),
        dark: UIColor(hex: 0x121110)
    )

    // Semantic Signals
    static let signal = adaptive(
        light: UIColor(hex: 0x15803D),
        dark: UIColor(hex: 0x4ADE80)
    )
    static let signalSoft = adaptive(
        light: UIColor(hex: 0x16A34A, alpha: 0.12),
        dark: UIColor(hex: 0x22C55E, alpha: 0.16)
    )
    static let success = adaptive(
        light: UIColor(hex: 0x047857),
        dark: UIColor(hex: 0x34D399)
    )
    static let successSoft = adaptive(
        light: UIColor(hex: 0x047857, alpha: 0.12),
        dark: UIColor(hex: 0x34D399, alpha: 0.15)
    )
    static let warning = adaptive(
        light: UIColor(hex: 0xB45309),
        dark: UIColor(hex: 0xFBBF24)
    )
    static let warningSoft = adaptive(
        light: UIColor(hex: 0xB45309, alpha: 0.12),
        dark: UIColor(hex: 0xFBBF24, alpha: 0.15)
    )
    static let error = adaptive(
        light: UIColor(hex: 0xDC2626),
        dark: UIColor(hex: 0xF87171)
    )
    static let errorSoft = adaptive(
        light: UIColor(hex: 0xDC2626, alpha: 0.11),
        dark: UIColor(hex: 0xF87171, alpha: 0.16)
    )

    // Borders & Grid
    static let border = adaptive(
        light: UIColor(hex: 0x181614, alpha: 0.09),
        dark: UIColor(hex: 0xF6F4EF, alpha: 0.11)
    )
    static let borderStrong = adaptive(
        light: UIColor(hex: 0x181614, alpha: 0.18),
        dark: UIColor(hex: 0xF6F4EF, alpha: 0.22)
    )
    static let gridLine = adaptive(
        light: UIColor(hex: 0x181614, alpha: 0.036),
        dark: UIColor(hex: 0xF6F4EF, alpha: 0.045)
    )
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Radii & Spacing

enum PKRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

enum PKSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

// MARK: - Typography

enum PKFont {
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .default, weight: weight)
    }

    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    static func mono(_ style: Font.TextStyle = .caption, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .monospaced, weight: weight).monospacedDigit()
    }
}

// MARK: - Haptics

@MainActor
enum PKHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Ambient Architectural Backdrop (Mirrors .pk-ambient-grid & halos)

struct PKStudioBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    var showGrid: Bool = true

    var body: some View {
        ZStack {
            PKColors.background

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                // Top-left warm orange ambient halo
                RadialGradient(
                    colors: [
                        PKColors.brandVivid.opacity(colorScheme == .dark ? 0.14 : 0.08),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: max(w, h) * 0.65
                )

                // Bottom-right subtle warm contrast halo
                RadialGradient(
                    colors: [
                        PKColors.brand.opacity(colorScheme == .dark ? 0.08 : 0.045),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 20,
                    endRadius: max(w, h) * 0.55
                )

                if showGrid {
                    Canvas { context, size in
                        let step: CGFloat = 44
                        var path = Path()
                        var x: CGFloat = 0
                        while x <= size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            x += step
                        }
                        var y: CGFloat = 0
                        while y <= size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            y += step
                        }
                        context.stroke(path, with: .color(PKColors.gridLine), lineWidth: 0.75)
                    }
                    .mask(
                        LinearGradient(
                            colors: [.black.opacity(0.85), .black.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surface & Card Modifiers

struct PKCardStyle: ViewModifier {
    var radius: CGFloat = PKRadius.md
    var backgroundColor: Color = PKColors.surface
    var borderColor: Color = PKColors.border
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct PKInsetCardStyle: ViewModifier {
    var radius: CGFloat = PKRadius.sm
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(PKColors.border, lineWidth: 1)
            )
    }
}

extension View {
    func pkCard(
        radius: CGFloat = PKRadius.md,
        background: Color = PKColors.surface,
        border: Color = PKColors.border,
        padding: CGFloat = 16
    ) -> some View {
        modifier(PKCardStyle(radius: radius, backgroundColor: background, borderColor: border, padding: padding))
    }

    func pkInsetCard(radius: CGFloat = PKRadius.sm, padding: CGFloat = 12) -> some View {
        modifier(PKInsetCardStyle(radius: radius, padding: padding))
    }
}

// MARK: - Tactile Button Styles

struct PKPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct PKPillButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case ink
        case secondary
        case ghost
        case destructive
    }

    let variant: Variant
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PKFont.body(compact ? .footnote : .subheadline, weight: .semibold))
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 9 : 13)
            .foregroundStyle(foregroundColor)
            .background(backgroundView)
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.76), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return .white
        case .ink: return PKColors.inkCTAText
        case .secondary: return PKColors.textPrimary
        case .ghost: return PKColors.textSecondary
        case .destructive: return .white
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            PKColors.brandVivid
        case .ink:
            PKColors.inkCTA
        case .secondary:
            PKColors.surface
        case .ghost:
            Color.clear
        case .destructive:
            PKColors.error
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return PKColors.borderStrong
        default: return .clear
        }
    }
}

// MARK: - Brand Logo & Wordmark

struct PKLogoMark: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(PKColors.espressoSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                        .strokeBorder(PKColors.espressoBorder, lineWidth: 1)
                )

            // Stylized architectural "P" + Signal Orange dot/bar matching client/public/logo.svg
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                Path { path in
                    path.move(to: CGPoint(x: s * 0.31, y: s * 0.72))
                    path.addLine(to: CGPoint(x: s * 0.31, y: s * 0.28))
                    path.addLine(to: CGPoint(x: s * 0.51, y: s * 0.28))
                    path.addCurve(
                        to: CGPoint(x: s * 0.67, y: s * 0.42),
                        control1: CGPoint(x: s * 0.61, y: s * 0.28),
                        control2: CGPoint(x: s * 0.67, y: s * 0.34)
                    )
                    path.addCurve(
                        to: CGPoint(x: s * 0.51, y: s * 0.56),
                        control1: CGPoint(x: s * 0.67, y: s * 0.50),
                        control2: CGPoint(x: s * 0.61, y: s * 0.56)
                    )
                    path.addLine(to: CGPoint(x: s * 0.39, y: s * 0.56))
                }
                .stroke(PKColors.espressoText, style: StrokeStyle(lineWidth: max(2.2, s * 0.085), lineCap: .round, lineJoin: .round))

                // Signal Orange underline bar
                RoundedRectangle(cornerRadius: s * 0.045, style: .continuous)
                    .fill(PKColors.brandVivid)
                    .frame(width: s * 0.28, height: max(2.5, s * 0.095))
                    .position(x: s * 0.56, y: s * 0.68)

                // Live Signal dot
                Circle()
                    .fill(PKColors.brandVivid)
                    .frame(width: max(3.5, s * 0.13), height: max(3.5, s * 0.13))
                    .position(x: s * 0.73, y: s * 0.29)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PKBrandWordmark: View {
    var fontSize: CGFloat = 22
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text("perkakasku")
                .foregroundStyle(onDark ? PKColors.espressoText : PKColors.textPrimary)
            Text(".")
                .foregroundStyle(PKColors.brandVivid)
        }
        .font(.system(size: fontSize, weight: .heavy, design: .default))
        .tracking(-0.6)
        .accessibilityLabel("Perkakasku")
    }
}

// MARK: - Badges & Live Signal Dot

struct PKLiveDot: View {
    var color: Color = PKColors.signal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(pulsing && !reduceMotion ? 1.35 : 1.0)
            .opacity(pulsing && !reduceMotion ? 0.6 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .accessibilityHidden(true)
    }
}

struct PKModeBadge: View {
    let mode: ProcessingMode

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(PKFont.mono(.caption2, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private var icon: String {
        switch mode {
        case .local: return "lock.fill"
        case .hybrid: return "cpu.fill"
        case .server: return "shield.checkered"
        }
    }

    private var label: String {
        switch mode {
        case .local: return "On-Device"
        case .hybrid: return "Hybrid"
        case .server: return "Sandbox"
        }
    }

    private var foreground: Color {
        switch mode {
        case .local: return PKColors.success
        case .hybrid, .server: return PKColors.brand
        }
    }

    private var background: Color {
        switch mode {
        case .local: return PKColors.successSoft
        case .hybrid, .server: return PKColors.brandSoft
        }
    }

    private var border: Color {
        switch mode {
        case .local: return PKColors.success.opacity(0.28)
        case .hybrid, .server: return PKColors.brandBorder
        }
    }
}

struct PKTagBadge: View {
    let text: String
    var icon: String? = nil
    var tone: Tone = .neutral

    enum Tone {
        case neutral, brand, success, warning, error
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(PKFont.mono(.caption2, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(fg)
        .background(bg, in: Capsule())
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private var fg: Color {
        switch tone {
        case .neutral: return PKColors.textSecondary
        case .brand: return PKColors.brand
        case .success: return PKColors.success
        case .warning: return PKColors.warning
        case .error: return PKColors.error
        }
    }

    private var bg: Color {
        switch tone {
        case .neutral: return PKColors.backgroundSecondary
        case .brand: return PKColors.brandSoft
        case .success: return PKColors.successSoft
        case .warning: return PKColors.warningSoft
        case .error: return PKColors.errorSoft
        }
    }

    private var border: Color {
        switch tone {
        case .neutral: return PKColors.border
        case .brand: return PKColors.brandBorder
        case .success: return PKColors.success.opacity(0.25)
        case .warning: return PKColors.warning.opacity(0.25)
        case .error: return PKColors.error.opacity(0.25)
        }
    }
}

// MARK: - Staggered Entrance Animation Modifier

struct PKStaggerAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                let delay = reduceMotion ? 0 : min(Double(index) * 0.045, 0.32)
                withAnimation(.spring(response: 0.44, dampingFraction: 0.84).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func pkStaggered(index: Int) -> some View {
        modifier(PKStaggerAppear(index: index))
    }
}
