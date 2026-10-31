import AppKit
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateController: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    private(set) var statusText = "Updates are not configured in this development build"
    private(set) var canCheckForUpdates = false
    private(set) var availableVersion: String?

    var isConfigured: Bool { updaterController != nil }

    var automaticChecksEnabled = false {
        didSet {
            guard let updater = updaterController?.updater,
                  updater.automaticallyChecksForUpdates != automaticChecksEnabled else { return }
            updater.automaticallyChecksForUpdates = automaticChecksEnabled
        }
    }

    @ObservationIgnored private var updaterController: SPUStandardUpdaterController?
    @ObservationIgnored private var availabilityObservation: NSKeyValueObservation?
    @ObservationIgnored private var automaticChecksObservation: NSKeyValueObservation?

    override init() {
        super.init()
        guard
            let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let url = URL(string: feed), url.scheme == "https", url.host != nil,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            Data(base64Encoded: key)?.count == 32
        else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self
        )
        updaterController = controller
        do {
            try controller.updater.start()
            statusText = "Automatic checks show an update here. Choose Check for Updates to install."
        } catch {
            statusText = "Updates could not start: \(error.localizedDescription)"
            updaterController = nil
            return
        }

        availabilityObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        automaticChecksObservation = controller.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.automaticChecksEnabled = updater.automaticallyChecksForUpdates
            }
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.checkForUpdates(nil)
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        availableVersion = update.displayVersionString
        statusText = "Version \(update.displayVersionString) is available."
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
        statusText = "Automatic checks show an update here. Choose Check for Updates to install."
    }
}
