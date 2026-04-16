import SwiftUI

// MARK: - Design Tokens

enum GlassStyle {
    static let panelRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 10
    static let chipRadius: CGFloat = 6

    /// UserDefaults key for the glass effect toggle.
    static let glassEnabledKey = "glassEffectEnabled"

    static func chipColor(for category: FormatCategory) -> Color {
        switch category {
        case .documents, .presentations: return Color(red: 0.35, green: 0.60, blue: 1.0)
        case .images:                    return Color(red: 1.0, green: 0.65, blue: 0.25)
        case .spreadsheets, .data:       return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .audio:                     return Color(red: 0.70, green: 0.45, blue: 1.0)
        case .web:                       return Color(red: 0.30, green: 0.80, blue: 0.85)
        default:                         return Color(red: 0.60, green: 0.60, blue: 0.65)
        }
    }
}

// MARK: - Glass-Enabled Environment Key

private struct GlassEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var glassEnabled: Bool {
        get { self[GlassEnabledKey.self] }
        set { self[GlassEnabledKey.self] = newValue }
    }
}

// MARK: - Window Background

/// A subtle gradient behind the window content so `.material` has color to blur.
struct GlassWindowBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassEnabled) private var glassEnabled

    var body: some View {
        if glassEnabled {
            ZStack {
                // Base: slightly warm dark or cool light
                (colorScheme == .dark
                    ? Color(red: 0.11, green: 0.11, blue: 0.14)
                    : Color(red: 0.95, green: 0.95, blue: 0.97))

                // Subtle colored radial gradients
                RadialGradient(
                    colors: [
                        Color.blue.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 300
                )
                RadialGradient(
                    colors: [
                        Color.purple.opacity(colorScheme == .dark ? 0.06 : 0.04),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 20,
                    endRadius: 250
                )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glass Panel Modifier

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = GlassStyle.panelRadius
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassEnabled) private var glassEnabled

    private var borderOpacity: Double { colorScheme == .dark ? 0.20 : 0.12 }
    private var highlightOpacity: Double { colorScheme == .dark ? 0.12 : 0.25 }

    func body(content: Content) -> some View {
        if glassEnabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.75)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(highlightOpacity),
                                    .white.opacity(highlightOpacity * 0.3),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08),
                    radius: 8, y: 4
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Glass Button Modifier

struct GlassButton: ViewModifier {
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassEnabled) private var glassEnabled

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(glassEnabled ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(isHovered ? Color.white.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .stroke(Color.white.opacity(isHovered ? 0.30 : 0.18), lineWidth: 0.75)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.10), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 4, y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: GlassStyle.buttonRadius))
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Accent Glass Button Modifier

struct AccentGlassButton: ViewModifier {
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(Color.accentColor.opacity(isHovered ? 0.30 : 0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 0.75)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
            .shadow(
                color: Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                radius: 6, y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: GlassStyle.buttonRadius))
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - View Extensions

extension View {
    func glassPanel(cornerRadius: CGFloat = GlassStyle.panelRadius) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }

    func glassButton() -> some View {
        modifier(GlassButton())
    }

    func accentGlassButton() -> some View {
        modifier(AccentGlassButton())
    }
}
