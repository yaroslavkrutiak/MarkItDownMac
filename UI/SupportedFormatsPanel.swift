import SwiftUI

/// Glass panel displaying color-coded format chips grouped by category.
struct SupportedFormatsPanel: View {
    let extensions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPORTED FORMATS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            FlowLayout(spacing: 5) {
                ForEach(extensions, id: \.self) { ext in
                    FormatChipView(ext: ext)
                }

                if extensions.count > 14 {
                    Text("+\(extensions.count - 14) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(12)
        .glassPanel()
    }
}

// MARK: - FlowLayout

/// A layout that wraps children to the next line when they exceed the width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { total, row in
            total + row.height + (total > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in 0..<row.count {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var count: Int
        var height: CGFloat
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentRowCount = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = currentRowCount > 0 ? size.width + spacing : size.width

            if currentRowWidth + neededWidth > maxWidth && currentRowCount > 0 {
                rows.append(Row(count: currentRowCount, height: currentRowHeight))
                currentRowWidth = size.width
                currentRowHeight = size.height
                currentRowCount = 1
            } else {
                currentRowWidth += neededWidth
                currentRowHeight = max(currentRowHeight, size.height)
                currentRowCount += 1
            }
        }

        if currentRowCount > 0 {
            rows.append(Row(count: currentRowCount, height: currentRowHeight))
        }

        return rows
    }
}
