import AppKit

struct ValidationLaunch {
    enum Appearance {
        case system
        case dark
        case highContrast
    }

    let showsWindow: Bool
    let showsPanel: Bool
    let freezesAfterSample: Bool
    let appearance: Appearance

    init(arguments: [String]) {
        showsWindow = arguments.contains("--show-window")
        showsPanel = arguments.contains("--show-panel")
        freezesAfterSample = arguments.contains("--freeze-after-sample")
        if !showsWindow {
            appearance = .system
        } else if arguments.contains("--high-contrast-appearance") {
            appearance = .highContrast
        } else if arguments.contains("--dark-appearance") {
            appearance = .dark
        } else {
            appearance = .system
        }
    }

    var isValidation: Bool { showsWindow || showsPanel }

    var applicationAppearance: NSAppearance? {
        switch appearance {
        case .system: nil
        case .dark: NSAppearance(named: .darkAqua)
        case .highContrast: NSAppearance(named: .accessibilityHighContrastAqua)
        }
    }
}
