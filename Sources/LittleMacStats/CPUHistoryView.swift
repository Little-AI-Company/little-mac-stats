import AppKit

struct CPUHistorySample {
    static let windowSeconds = 60
    static let window = TimeInterval(windowSeconds)

    let timestamp: Date
    let percent: Double?
}

@MainActor
final class CPUHistoryView: NSView {
    private var samples: [CPUHistorySample] = []
    private var endTime = Date()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("CPU usage line chart over the last \(CPUHistorySample.windowSeconds) seconds")
    }
    required init?(coder: NSCoder) { nil }

    func update(samples: [CPUHistorySample], endTime: Date) {
        self.samples = samples
        self.endTime = endTime
        let measured = samples.filter { $0.percent != nil && endTime.timeIntervalSince($0.timestamp) <= CPUHistorySample.window }
        let values = measured.compactMap(\.percent)
        let current = samples.last?.percent.map { "Current \(Int($0.rounded())) percent." } ?? "Current reading unavailable."
        if let first = measured.first, let minimum = values.min(), let maximum = values.max() {
            let duration = max(0, Int(endTime.timeIntervalSince(first.timestamp).rounded()))
            let count = values.count == 1 ? "1 measured sample" : "\(values.count) measured samples"
            setAccessibilityValue("\(current) \(count) over \(duration) seconds. Minimum \(Int(minimum.rounded())) percent, maximum \(Int(maximum.rounded())) percent. Scale 0 to 100 percent of total CPU capacity.")
        } else {
            setAccessibilityValue("\(current) Collecting measured samples. Scale 0 to 100 percent of total CPU capacity.")
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let plot = NSRect(x: 0, y: 18, width: max(0, bounds.width - 40), height: max(0, bounds.height - 24))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        NSColor.separatorColor.setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 0.5
        for y in [plot.minY, plot.maxY] {
            grid.move(to: NSPoint(x: plot.minX, y: y))
            grid.line(to: NSPoint(x: plot.maxX, y: y))
        }
        grid.stroke()
        ("100%" as NSString).draw(at: NSPoint(x: plot.maxX + 5, y: plot.maxY - 6), withAttributes: attributes)
        ("0%" as NSString).draw(at: NSPoint(x: plot.maxX + 5, y: plot.minY - 5), withAttributes: attributes)
        ("\(CPUHistorySample.windowSeconds) seconds ago" as NSString).draw(at: NSPoint(x: plot.minX, y: 0), withAttributes: attributes)
        let now = "Now" as NSString
        now.draw(at: NSPoint(x: plot.maxX - now.size(withAttributes: attributes).width, y: 0), withAttributes: attributes)

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()
        let line = NSBezierPath()
        line.lineWidth = 1.5
        line.lineJoinStyle = .round
        var previous: CPUHistorySample?
        for sample in samples {
            let elapsed = endTime.timeIntervalSince(sample.timestamp)
            guard elapsed >= 0, elapsed <= CPUHistorySample.window, let percent = sample.percent else {
                previous = nil
                continue
            }
            let point = NSPoint(x: plot.maxX - plot.width * elapsed / CPUHistorySample.window,
                                y: plot.minY + plot.height * max(0, min(percent, 100)) / 100)
            if let previous, previous.percent != nil,
               sample.timestamp.timeIntervalSince(previous.timestamp) <= 5 {
                line.line(to: point)
            } else {
                line.move(to: point)
            }
            NSBezierPath(ovalIn: NSRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)).fill()
            previous = sample
        }
        line.stroke()
    }
}
