import SwiftUI

// MARK: - Design Tokens

enum GlassStyle {
    static let panelRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 10
    static let chipRadius: CGFloat = 6

    static func chipColor(for category: FormatCategory) -> Color {
        switch category {
        case .documents, .presentations: return .blue
        case .images:                    return .orange
        case .spreadsheets, .data:       return .green
        case .audio:                     return .purple
        case .web:                       return .cyan
        default:                         return .gray
        }
    }
}

// MARK: - Glass Panel Modifier

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = GlassStyle.panelRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .overlay(
                // Specular top-edge highlight
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - Glass Button Modifier

struct GlassButton: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                            .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .stroke(Color.white.opacity(isHovered ? 0.25 : 0.15), lineWidth: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: GlassStyle.buttonRadius))
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Accent Glass Button Modifier

struct AccentGlassButton: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(Color.accentColor.opacity(isHovered ? 0.25 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.buttonRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
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
