import AppKit
import Observation
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let updates: UpdateController
    private let loginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let automaticButton = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let checkButton = NSButton(title: "Check for Updates…", target: nil, action: nil)
    private let controls = NSStackView()

    init(updates: UpdateController) {
        self.updates = updates
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Mac Stats Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 420, height: 300)
        super.init(window: window)
        window.delegate = self
        window.center()
        configure()
        observeUpdates()
    }
    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        refreshLoginState()
        super.showWindow(sender)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshLoginState()
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
            label.font = .systemFont(ofSize: NSFont.systemFontSize)
            label.textColor = .labelColor
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        let startupTitle = NSTextField(labelWithString: "Startup")
        let updatesTitle = NSTextField(labelWithString: "Updates")
        for title in [startupTitle, updatesTitle] {
            title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        }
        let stack = controls
        for view in [startupTitle, loginButton, loginStatus, updatesTitle, automaticButton, updateStatus, checkButton] {
            stack.addArrangedSubview(view)
        }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(20, after: loginStatus)
        stack.setCustomSpacing(12, after: updateStatus)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        let bottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            bottom,
            loginStatus.widthAnchor.constraint(equalTo: stack.widthAnchor),
            updateStatus.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window?.initialFirstResponder = loginButton
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
        fitWindowToControls()
    }

    private func refreshLoginState() {
        let status = SMAppService.mainApp.status
        loginButton.state = status == .enabled || status == .requiresApproval ? .on : .off
        loginButton.isEnabled = true
        switch status {
        case .enabled: loginStatus.stringValue = "Mac Stats will start when you log in."
        case .requiresApproval: loginStatus.stringValue = "Launch at login needs approval in System Settings → General → Login Items."
        case .notFound: loginStatus.stringValue = "Launch at login is not registered. Enable it to set it up."
        case .notRegistered: loginStatus.stringValue = "Mac Stats will start only when you open it."
        @unknown default: loginStatus.stringValue = "Launch at login status is unavailable."
        }
        fitWindowToControls()
    }

    private func fitWindowToControls() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let height = max(300, controls.fittingSize.height + 48)
        guard abs(content.frame.height - height) > 1 else { return }
        window.setContentSize(NSSize(width: 420, height: height))
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
