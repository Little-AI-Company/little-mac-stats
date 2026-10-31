import AppKit

@main
enum LittleMacStatsApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let launch = ValidationLaunch(arguments: CommandLine.arguments)
        application.setActivationPolicy(launch.isValidation ? .regular : .accessory)
        if let appearance = launch.applicationAppearance {
            application.appearance = appearance
        }
        let delegate = ApplicationDelegate(launch: launch)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
