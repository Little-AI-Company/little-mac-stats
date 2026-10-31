import AppKit

@MainActor
enum StatusDisplayRenderer {
    static func levels(corePercentages: [Double]?, coreCount: Int) -> [Int] {
        let count = max(1, coreCount)
        guard let corePercentages, corePercentages.count == count else {
            return Array(repeating: 0, count: count)
        }
        return corePercentages.map { percent in
            guard percent.isFinite else { return 0 }
            switch percent {
            case ..<10: return 0
            case ..<40: return 1
            case ..<75: return 2
            default: return 3
            }
        }
    }

    static func image(corePercentages: [Double]?, coreCount: Int) -> NSImage {
        image(levels: levels(corePercentages: corePercentages, coreCount: coreCount))
    }

    private enum Layout {
        static let twoRowCoreLimit = 24
        static let fewCoreRows = 2
        static let manyCoreRows = 4
        static let denseColumnLimit = 64
        static let gap = 1.0
        static let denseGap = 0.25
        static let fewCoreBlockSize = 6.0
        static let manyCoreBlockSize = 3.0
        static let minimumBlockSize = 0.1
        static let maximumWidth = 96.0
    }

    static func image(levels: [Int]) -> NSImage {
        let levels = levels.isEmpty ? [0] : levels
        let rows = min(levels.count, levels.count > Layout.twoRowCoreLimit ? Layout.manyCoreRows : Layout.fewCoreRows)
        let columns = (levels.count + rows - 1) / rows
        let gap = columns > Layout.denseColumnLimit ? Layout.denseGap : Layout.gap
        let blockSize = min(rows <= Layout.fewCoreRows ? Layout.fewCoreBlockSize : Layout.manyCoreBlockSize,
                            max(Layout.minimumBlockSize,
                                (Layout.maximumWidth - Double(columns - 1) * gap) / Double(columns)))
        let size = NSSize(width: Double(columns) * blockSize + Double(columns - 1) * gap,
                          height: Double(rows) * blockSize + Double(rows - 1) * gap)
        let image = NSImage(size: size, flipped: true) { _ in
            let strokeWidth = min(1.0, blockSize / 3)
            for (index, level) in levels.enumerated() {
                let frame = NSRect(x: Double(index % columns) * (blockSize + gap),
                                   y: Double(index / columns) * (blockSize + gap),
                                   width: blockSize, height: blockSize)
                if level > 0 {
                    let opacity = level == 1 ? 0.25 : level == 2 ? 0.55 : 1.0
                    NSColor.black.withAlphaComponent(opacity).setFill()
                    frame.fill()
                }
                NSColor.black.setStroke()
                let outline = NSBezierPath(rect: frame.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
                outline.lineWidth = strokeWidth
                outline.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "CPU usage by core"
        return image
    }
}
