import AppKit

@main
enum LittleMacStatsApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let validationLaunch = CommandLine.arguments.contains("--show-window") || CommandLine.arguments.contains("--show-panel")
        application.setActivationPolicy(validationLaunch ? .regular : .accessory)
        if CommandLine.arguments.contains("--show-window") {
            if CommandLine.arguments.contains("--high-contrast-appearance") {
                application.appearance = NSAppearance(named: .accessibilityHighContrastAqua)
            } else if CommandLine.arguments.contains("--dark-appearance") {
                application.appearance = NSAppearance(named: .darkAqua)
            }
        }
        let delegate = ApplicationDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
