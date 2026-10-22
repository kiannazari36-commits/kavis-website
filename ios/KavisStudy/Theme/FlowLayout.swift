import SwiftUI

/// Puts views in rows and starts a new row when the line is full (chips, tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    private func rows(_ subviews: Subviews, in width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            let w = view.sizeThatFits(.unspecified).width
            if x > 0, x + w > width { rows.append([]); x = 0 }
            rows[rows.count - 1].append(i)
            x += w + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var widest: CGFloat = 0
        let all = rows(subviews, in: width)
        for (index, row) in all.enumerated() {
            var rowHeight: CGFloat = 0
            var rowWidth: CGFloat = 0
            for i in row {
                let size = subviews[i].sizeThatFits(.unspecified)
                rowHeight = max(rowHeight, size.height)
                rowWidth += size.width
            }
            rowWidth += spacing * CGFloat(max(row.count - 1, 0))
            widest = max(widest, rowWidth)
            totalHeight += rowHeight
            if index < all.count - 1 { totalHeight += rowSpacing }
        }
        return CGSize(width: proposal.width ?? widest, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, in: bounds.width) {
            let sizes = row.map { subviews[$0].sizeThatFits(.unspecified) }
            let rowWidth = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0))
            var x = bounds.minX
            switch alignment {
            case .center: x += (bounds.width - rowWidth) / 2
            case .trailing: x += bounds.width - rowWidth
            default: break
            }
            for (k, i) in row.enumerated() {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[k]))
                x += sizes[k].width + spacing
            }
            y += (sizes.map(\.height).max() ?? 0) + rowSpacing
        }
    }
}
