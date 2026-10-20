import AppKit

@MainActor
final class CPUUsageBarView: NSView {
    var percent: Double? {
        didSet {
            if percent != oldValue { needsDisplay = true }
        }
    }

    var emphasized = false {
        didSet {
            if emphasized != oldValue { needsDisplay = true }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = NSRect(x: 0, y: (bounds.height - 4) / 2, width: bounds.width, height: 4)
        (emphasized ? NSColor.selectedControlTextColor.withAlphaComponent(0.25) : NSColor.quaternaryLabelColor).setFill()
        NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
        guard let percent else { return }
        let fill = NSRect(x: track.minX, y: track.minY,
                          width: track.width * max(0, min(percent, 100)) / 100, height: track.height)
        (emphasized ? NSColor.selectedControlTextColor : NSColor.labelColor).setFill()
        NSBezierPath(roundedRect: fill, xRadius: 2, yRadius: 2).fill()
    }
}

@MainActor
final class CPUUsageCellView: NSTableCellView {
    let usageBar = CPUUsageBarView()

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { usageBar.emphasized = backgroundStyle == .emphasized }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        usageBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(usageBar)
        addSubview(label)
        textField = label
        NSLayoutConstraint.activate([
            usageBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            usageBar.widthAnchor.constraint(equalToConstant: 54),
            usageBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            usageBar.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: usageBar.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
}
