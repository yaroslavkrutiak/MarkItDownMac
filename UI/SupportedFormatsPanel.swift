import SwiftUI

/// Compact glass panel showing key format chips with an overflow count.
struct SupportedFormatsPanel: View {
    let extensions: [String]

    private let maxVisible = 12

    private var visible: [String] {
        Array(extensions.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, extensions.count - maxVisible)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(extensions.count) SUPPORTED FORMATS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.8)

            FlowLayout(spacing: 4) {
                ForEach(visible, id: \.self) { ext in
                    FormatChipView(ext: ext)
                }

                if overflowCount > 0 {
                    Text("+\(overflowCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: GlassStyle.chipRadius)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(10)
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
