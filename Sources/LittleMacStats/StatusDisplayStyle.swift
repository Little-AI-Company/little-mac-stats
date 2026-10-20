import AppKit

enum StatusDisplayStyle: String, CaseIterable {
    case coreBlocks
    case percentage

    var title: String {
        switch self {
        case .coreBlocks: "CPU Cores"
        case .percentage: "Percentage"
        }
    }

    @MainActor
    func previewImage(coreCount: Int) -> NSImage {
        switch self {
        case .coreBlocks:
            let levels = (0..<max(1, coreCount)).map { $0 % 4 }
            return StatusDisplayRenderer.image(levels: levels)
        case .percentage:
            let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let text = "42%" as NSString
            let image = NSImage(size: text.size(withAttributes: attributes), flipped: false) { _ in
                text.draw(at: .zero, withAttributes: attributes)
                return true
            }
            image.isTemplate = true
            image.accessibilityDescription = "Percentage display preview"
            return image
        }
    }
}
