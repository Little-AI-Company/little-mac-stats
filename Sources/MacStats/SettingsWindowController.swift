import AppKit
import Observation
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController {
    private let updates: UpdateController
    private let loginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let automaticButton = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let checkButton = NSButton(title: "Check for Updates…", target: nil, action: nil)

    init(updates: UpdateController) {
        self.updates = updates
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Mac Stats Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        configure()
        observeUpdates()
    }
    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        refreshLoginState()
        super.showWindow(sender)
    }

    private func configure() {
        guard let content = window?.contentView else { return }
        loginButton.target = self
        loginButton.action = #selector(toggleLogin(_:))
        automaticButton.target = self
        automaticButton.action = #selector(toggleAutomaticUpdates(_:))
        checkButton.target = self
        checkButton.action = #selector(checkUpdates(_:))
        for label in [loginStatus, updateStatus] {
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
        }
        let description = NSTextField(wrappingLabelWithString: "Mac Stats samples total CPU every two seconds, and process CPU once per second while the panel is open.")
        description.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [loginButton, loginStatus, automaticButton, updateStatus, checkButton, description])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20)
        ])
        refreshLoginState()
        refreshUpdates()
    }

    private func observeUpdates() {
        withObservationTracking {
            _ = updates.automaticChecksEnabled
            _ = updates.statusText
            _ = updates.canCheckForUpdates
            _ = updates.isConfigured
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshUpdates()
                self?.observeUpdates()
            }
        }
    }

    private func refreshUpdates() {
        automaticButton.state = updates.automaticChecksEnabled ? .on : .off
        automaticButton.isEnabled = updates.isConfigured
        checkButton.isEnabled = updates.canCheckForUpdates
        updateStatus.stringValue = updates.statusText
    }

    private func refreshLoginState() {
        let status = SMAppService.mainApp.status
        loginButton.state = status == .enabled || status == .requiresApproval ? .on : .off
        loginButton.isEnabled = status != .notFound
        switch status {
        case .enabled: loginStatus.stringValue = "Mac Stats will start when you log in."
        case .requiresApproval: loginStatus.stringValue = "Allow Mac Stats in System Settings → General → Login Items."
        case .notFound: loginStatus.stringValue = "Move Mac Stats to Applications, then reopen it to enable launch at login."
        case .notRegistered: loginStatus.stringValue = "Mac Stats will start only when you open it."
        @unknown default: loginStatus.stringValue = "Launch at login status is unavailable."
        }
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginState()
        } catch {
            refreshLoginState()
            let alert = NSAlert()
            alert.messageText = "Could not change launch at login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func toggleAutomaticUpdates(_ sender: NSButton) {
        updates.automaticChecksEnabled = sender.state == .on
        refreshUpdates()
    }

    @objc private func checkUpdates(_ sender: Any?) { updates.checkForUpdates() }
}
