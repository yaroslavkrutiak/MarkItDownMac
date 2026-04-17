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

    private var specularTop: Color { colorScheme == .dark ? .white.opacity(0.45) : .white.opacity(0.78) }
    private var specularMid: Color { colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.10) }
    private var specularBottom: Color { colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.24) }
    private var sheenOpacity: Double { colorScheme == .dark ? 0.16 : 0.32 }

    func body(content: Content) -> some View {
        if glassEnabled {
            content
                // Layer 1 — blurred & saturated backdrop
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                )
                // Layer 2 — inner light sheen concentrated on the upper third
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(sheenOpacity), location: 0.0),
                                    .init(color: .white.opacity(sheenOpacity * 0.25), location: 0.35),
                                    .init(color: .clear, location: 0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                )
                // Layer 3 — specular edge: bright at top, dim mid, faint rim-light at bottom
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: specularTop, location: 0.0),
                                    .init(color: specularMid, location: 0.55),
                                    .init(color: specularBottom, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10),
                    radius: 10, y: 4
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

    private var specularTop: Color {
        colorScheme == .dark
            ? .white.opacity(isHovered ? 0.55 : 0.40)
            : .white.opacity(isHovered ? 0.90 : 0.72)
    }
    private var specularBottom: Color {
        colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.18)
    }
    private var sheenOpacity: Double {
        colorScheme == .dark ? (isHovered ? 0.16 : 0.10) : (isHovered ? 0.30 : 0.18)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            // Layer 1 — blurred + saturated backdrop
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(glassEnabled
                          ? AnyShapeStyle(.thinMaterial)
                          : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.5)))
            )
            // Layer 2 — hover wash
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
            // Layer 3 — inner light sheen on the top edge
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(sheenOpacity), location: 0.0),
                                .init(color: .white.opacity(sheenOpacity * 0.3), location: 0.45),
                                .init(color: .clear, location: 0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            // Layer 4 — specular edge gradient
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [specularTop, specularBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.06),
                radius: isHovered ? 6 : 4, y: 2
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
            // Layer 1 — tinted accent fill (deeper on hover)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(isHovered ? 0.38 : 0.26),
                                Color.accentColor.opacity(isHovered ? 0.22 : 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            // Layer 2 — inner specular sheen
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isHovered ? 0.28 : 0.18), location: 0.0),
                                .init(color: .white.opacity(0.04), location: 0.45),
                                .init(color: .clear, location: 0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            // Layer 3 — specular edge tinted toward accent
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.50 : 0.75),
                                Color.accentColor.opacity(0.55),
                                Color.accentColor.opacity(0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(
                color: Color.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.14),
                radius: isHovered ? 8 : 6, y: 2
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
