import AppKit

@main
enum MacStatsApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let validationLaunch = CommandLine.arguments.contains("--show-window") || CommandLine.arguments.contains("--show-panel")
        application.setActivationPolicy(validationLaunch ? .regular : .accessory)
        let delegate = ApplicationDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
