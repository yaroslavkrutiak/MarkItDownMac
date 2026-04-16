import SwiftUI

/// A small colored pill showing a file extension, tinted by its format category.
struct FormatChipView: View {
    let ext: String

    private var category: FormatCategory {
        FormatCategory.category(for: ext)
    }

    private var color: Color {
        GlassStyle.chipColor(for: category)
    }

    var body: some View {
        Text(ext.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .default))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                    .stroke(color.opacity(0.30), lineWidth: 0.75)
            )
    }
}
