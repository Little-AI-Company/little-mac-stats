import AppKit
import ProcessCore

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSMenuItemValidation, NSWindowDelegate {
    private let sampler = ProcessSampler()
    private let terminator = ProcessTerminator()
    private let updates = UpdateController()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var panel: ProcessPanelController?
    private var settings: SettingsWindowController?
    private var validationWindow: NSWindow?
    private var samplingTask: Task<Void, Never>?
    private var sampleGeneration = 0
    private var hasSystemBaseline = false
    private var hasProcessBaseline = false
    private var sleeping = false
    private var renderedMeterLevel: Int?
    private var meterHasRendered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        let panel = ProcessPanelController(terminator: terminator, updates: updates)
        panel.onSettings = { [weak self] in self?.showSettings(nil) }
        panel.onClose = { [weak self] in
            guard let self else { return }
            if let window = self.validationWindow { window.performClose(nil) }
            else { self.popover.performClose(nil) }
        }
        self.panel = panel
        if CommandLine.arguments.contains("--show-window") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 450),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Mac Stats"
            window.contentViewController = panel
            window.setContentSize(NSSize(width: 420, height: 450))
            window.contentMinSize = NSSize(width: 420, height: 450)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            validationWindow = window
            showValidationWindow()
        } else {
            popover.contentViewController = panel
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 450)

        let item = NSStatusBar.system.statusItem(withLength: 30)
        if let button = item.button {
            button.image = CPUMeter.image(percent: nil)
            button.target = self
            button.action = #selector(togglePanel(_:))
            button.toolTip = "Mac Stats: measuring CPU usage"
            button.setAccessibilityLabel("Mac Stats")
            button.setAccessibilityHelp("Open CPU usage and running processes")
        }
        statusItem = item
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        startSampling()
        if validationWindow == nil && CommandLine.arguments.contains("--show-panel") {
            togglePanel(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        samplingTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if let window = validationWindow {
            if window.isVisible && !window.isMiniaturized { window.performClose(sender) }
            else { showValidationWindow(); startSampling() }
            return
        }
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            panel?.focusTable()
        }
    }

    func popoverWillShow(_ notification: Notification) {
        hasProcessBaseline = false
        panel?.beginMeasuring()
        startSampling()
    }

    func popoverDidClose(_ notification: Notification) {
        hasProcessBaseline = false
        startSampling()
    }

    private var isProcessPanelVisible: Bool {
        if let window = validationWindow { return window.isVisible && !window.isMiniaturized }
        return popover.isShown
    }

    private func showValidationWindow() {
        hasProcessBaseline = false
        panel?.beginMeasuring()
        validationWindow?.title = "Mac Stats"
        validationWindow?.deminiaturize(nil)
        validationWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel?.focusTable()
    }

    func windowWillClose(_ notification: Notification) {
        hasProcessBaseline = false
        startSampling()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        hasProcessBaseline = false
        startSampling()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        hasProcessBaseline = false
        panel?.beginMeasuring()
        startSampling()
    }

    private func startSampling() {
        samplingTask?.cancel()
        sampleGeneration += 1
        guard !sleeping else { return }
        let generation = sampleGeneration
        samplingTask = Task { [weak self, sampler] in
            while !Task.isCancelled {
                guard let self, generation == self.sampleGeneration else { return }
                let detailed = self.isProcessPanelVisible
                do {
                    let snapshot = try await sampler.sample(includeProcesses: detailed)
                    guard !Task.isCancelled, generation == self.sampleGeneration else { return }
                    let systemReady = self.hasSystemBaseline
                    let processesReady = self.hasProcessBaseline
                    self.hasSystemBaseline = true
                    if detailed { self.hasProcessBaseline = true }
                    self.render(snapshot, systemReady: systemReady, processesReady: processesReady)
                    // Windowed validation may pause after two real samples for stable native control inspection.
                    if detailed && processesReady && CommandLine.arguments.contains("--freeze-after-sample"),
                       let window = self.validationWindow {
                        window.title = "Mac Stats Validation Snapshot"
                        return
                    }
                } catch {
                    guard !Task.isCancelled, generation == self.sampleGeneration else { return }
                    self.updateMeter(nil)
                    self.statusItem?.button?.toolTip = "Mac Stats: CPU sampling unavailable"
                    self.panel?.showSamplingError(error.localizedDescription)
                }
                do {
                    try await Task.sleep(for: detailed ? .seconds(1) : .seconds(2))
                } catch { return }
            }
        }
    }

    private func render(_ snapshot: SamplingSnapshot, systemReady: Bool, processesReady: Bool) {
        let value = systemReady ? snapshot.systemCPUPercent : nil
        updateMeter(value)
        statusItem?.button?.toolTip = value.map { "Mac Stats: \(Int($0.rounded()))% of total CPU capacity" }
            ?? "Mac Stats: measuring CPU usage"
        statusItem?.button?.setAccessibilityValue(value.map { "\(Int($0.rounded())) percent CPU" } ?? "Measuring CPU")
        if snapshot.includesProcesses {
            panel?.update(snapshot, systemReady: systemReady, processesReady: processesReady)
        }
    }

    @objc private func willSleep(_ notification: Notification) {
        sleeping = true
        samplingTask?.cancel()
        sampleGeneration += 1
        popover.performClose(nil)
        if validationWindow != nil { panel?.showSamplingError("Sampling paused during sleep.") }
        updateMeter(nil)
        statusItem?.button?.toolTip = "Mac Stats: sampling paused during sleep"
    }

    @objc private func didWake(_ notification: Notification) {
        hasSystemBaseline = false
        hasProcessBaseline = false
        if isProcessPanelVisible { panel?.beginMeasuring() }
        Task {
            await sampler.reset()
            sleeping = false
            startSampling()
        }
    }

    @objc func showSettings(_ sender: Any?) {
        popover.performClose(nil)
        if settings == nil { settings = SettingsWindowController(updates: updates) }
        settings?.showWindow(sender)
        settings?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates(_ sender: Any?) { updates.checkForUpdates() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(checkForUpdates(_:)) || updates.canCheckForUpdates
    }

    private func updateMeter(_ percent: Double?) {
        let level = percent.map { Int((max(0, min($0, 100)) * 18 / 100).rounded()) }
        guard !meterHasRendered || level != renderedMeterLevel else { return }
        meterHasRendered = true
        renderedMeterLevel = level
        statusItem?.button?.image = CPUMeter.image(percent: level.map { Double($0) * 100 / 18 })
    }

    private func installMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Mac Stats")
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        applicationMenu.addItem(settingsItem)
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        applicationMenu.addItem(updateItem)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(NSMenuItem(title: "Quit Mac Stats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }
}
