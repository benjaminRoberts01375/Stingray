// Implements a custom layout for centering and wrapping items in rows, suitable for tvOS 18 and SwiftUI

import SwiftUI

public struct CenterWrappedRowsLayout: Layout {
    var itemWidth: CGFloat
    var itemHeight: CGFloat
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    
    public init(itemWidth: CGFloat, itemHeight: CGFloat, horizontalSpacing: CGFloat = 50, verticalSpacing: CGFloat = 50) {
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let totalWidth = proposal.replacingUnspecifiedDimensions().width
        
        var x: CGFloat = 0
        var rowCount = 1
        for _ in subviews {
            if x + itemWidth > totalWidth {
                rowCount += 1
                x = 0
            }
            x += itemWidth + horizontalSpacing
        }
        let totalHeight = (CGFloat(rowCount) * itemHeight) + (CGFloat(max(0, rowCount - 1)) * verticalSpacing)
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let totalWidth = bounds.width
        var rows: [[Int]] = [[]]
        var currentRowWidth: CGFloat = 0
        var currentRow: [Int] = []
        
        for index in subviews.indices {
            if currentRowWidth + itemWidth > totalWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
                currentRowWidth = 0
            }
            currentRow.append(index)
            if currentRowWidth > 0 {
                currentRowWidth += horizontalSpacing
            }
            currentRowWidth += itemWidth
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        if rows.first?.isEmpty == true { rows.removeFirst() }
        
        var yOffset: CGFloat = bounds.minY
        for row in rows {
            let rowItemCount = row.count
            let rowWidth = CGFloat(rowItemCount) * itemWidth + CGFloat(max(0, rowItemCount - 1)) * horizontalSpacing
            let xOffsetStart = bounds.minX + (totalWidth - rowWidth) / 2
            var xOffset: CGFloat = xOffsetStart
            for idx in row {
                let point = CGPoint(x: xOffset, y: yOffset)
                subviews[idx].place(at: point, proposal: ProposedViewSize(width: itemWidth, height: itemHeight))
                xOffset += itemWidth + horizontalSpacing
            }
            yOffset += itemHeight + verticalSpacing
        }
    }
}
