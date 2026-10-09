import AppKit

@MainActor
enum CPUMeter {
    static func image(percent: Double?) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 14), flipped: false) { bounds in
            let frame = NSRect(x: 1, y: 3, width: bounds.width - 2, height: 8)
            NSColor.black.setStroke()
            let border = NSBezierPath(rect: frame)
            border.lineWidth = 1
            border.stroke()
            if let percent {
                let fraction = max(0, min(percent / 100, 1))
                let fill = NSRect(x: frame.minX + 1, y: frame.minY + 1,
                                  width: (frame.width - 2) * fraction, height: frame.height - 2)
                NSColor.black.setFill()
                fill.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Mac Stats CPU usage"
        return image
    }
}
