import AppKit
import Observation
import ProcessCore

@MainActor
private final class GroupRow: NSObject {
    var group: ProcessGroup
    var children: [ProcessRow]
    init(_ group: ProcessGroup) {
        self.group = group
        children = group.processes.map(ProcessRow.init)
    }
}

@MainActor
private final class ProcessRow: NSObject {
    var process: ProcessSample
    init(_ process: ProcessSample) { self.process = process }
}

@MainActor
private final class ProcessOutlineView: NSOutlineView {
    var onClose: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onClose?() } else { super.keyDown(with: event) }
    }
}

@MainActor
final class ProcessPanelController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var onSettings: (() -> Void)?
    var onClose: (() -> Void)?
    private let terminator: ProcessTerminator
    private let updates: UpdateController
    private let updateButton = NSButton(title: "Check for Updates…", target: nil, action: nil)
    private let totalLabel = NSTextField(labelWithString: "CPU: measuring…")
    private let sampleLabel = NSTextField(labelWithString: "Collecting a process sample…")
    private let unavailableLabel = NSTextField(wrappingLabelWithString: "")
    private let outline = ProcessOutlineView()
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private let forceQuitButton = NSButton(title: "Force Quit…", target: nil, action: nil)
    private var groups: [GroupRow] = []
    private var processesReady = false
    private var terminating = false

    init(terminator: ProcessTerminator, updates: UpdateController) {
        self.terminator = terminator
        self.updates = updates
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        preferredContentSize = NSSize(width: 420, height: 450)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 450))
        totalLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        sampleLabel.font = .systemFont(ofSize: 11)
        sampleLabel.textColor = .secondaryLabelColor
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "App or process"
        nameColumn.width = 300
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .autoresizingMask
        let cpuColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cpu"))
        cpuColumn.title = "CPU"
        cpuColumn.width = 65
        cpuColumn.minWidth = 65
        cpuColumn.maxWidth = 65
        cpuColumn.resizingMask = []
        outline.addTableColumn(nameColumn)
        outline.addTableColumn(cpuColumn)
        outline.outlineTableColumn = nameColumn
        outline.delegate = self
        outline.dataSource = self
        outline.rowHeight = 24
        outline.intercellSpacing = NSSize(width: 4, height: 0)
        outline.style = .plain
        outline.indentationPerLevel = 12
        outline.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outline.frame = NSRect(x: 0, y: 0, width: 394, height: 230)
        outline.autoresizingMask = [.width]
        outline.allowsMultipleSelection = false
        outline.setAccessibilityLabel("CPU usage by app and process")
        outline.onClose = { [weak self] in self?.onClose?() }
        let scrollView = NSScrollView()
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.setAccessibilityLabel("Running apps and processes")

        let explanation = NSTextField(wrappingLabelWithString: "100% means your Mac is fully busy. Apps include the work they start.")
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor
        unavailableLabel.font = .systemFont(ofSize: 11)
        unavailableLabel.textColor = .secondaryLabelColor
        quitButton.target = self
        quitButton.action = #selector(quitSelected(_:))
        forceQuitButton.target = self
        forceQuitButton.action = #selector(forceQuitSelected(_:))
        quitButton.toolTip = "Request that the selected app or process quits"
        forceQuitButton.toolTip = "Immediately stop the selected app or process after confirmation"
        let settingsButton = NSButton(title: "Settings…", target: self, action: #selector(showSettings(_:)))
        let actions = NSStackView(views: [quitButton, forceQuitButton, NSView(), settingsButton])
        actions.orientation = .horizontal
        actions.spacing = 8
        updateButton.target = self
        updateButton.action = #selector(checkUpdates(_:))
        let quitAppButton = NSButton(title: "Quit Mac Stats", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        let applicationActions = NSStackView(views: [updateButton, NSView(), quitAppButton])
        applicationActions.orientation = .horizontal
        applicationActions.spacing = 8
        for component in [totalLabel, sampleLabel, scrollView, explanation, unavailableLabel, actions, applicationActions] {
            component.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(component)
        }
        NSLayoutConstraint.activate([
            totalLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            totalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            sampleLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            sampleLabel.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            sampleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            explanation.topAnchor.constraint(equalTo: sampleLabel.bottomAnchor, constant: 4),
            explanation.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            explanation.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            unavailableLabel.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 3),
            unavailableLabel.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            unavailableLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            actions.topAnchor.constraint(equalTo: unavailableLabel.bottomAnchor, constant: 8),
            actions.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            actions.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            applicationActions.topAnchor.constraint(equalTo: actions.bottomAnchor, constant: 6),
            applicationActions.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            applicationActions.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            applicationActions.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 230),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
        updateActions()
        refreshUpdates()
        observeUpdates()
    }

    func focusTable() {
        view.window?.makeFirstResponder(outline)
    }

    func beginMeasuring() {
        loadViewIfNeeded()
        processesReady = false
        sampleLabel.stringValue = "Collecting a process sample…"
        unavailableLabel.stringValue = ""
        groups = []
        outline.reloadData()
        updateActions()
    }

    func update(_ snapshot: SamplingSnapshot, systemReady: Bool, processesReady: Bool) {
        loadViewIfNeeded()
        self.processesReady = processesReady
        totalLabel.stringValue = systemReady
            ? "CPU: \(snapshot.systemCPUPercent.formatted(.number.precision(.fractionLength(1))))%"
            : "CPU: measuring…"
        sampleLabel.stringValue = processesReady
            ? "\(snapshot.groups.count) apps and processes"
            : "Measuring app usage…"
        unavailableLabel.stringValue = snapshot.unavailableProcessCount > 0
            ? "Some process details are unavailable."
            : ""
        unavailableLabel.toolTip = snapshot.unavailableProcessCount > 0
            ? "\(snapshot.unavailableProcessCount) process readings unavailable. Total CPU includes all work."
            : nil
        apply(snapshot.groups)
        updateActions()
    }

    func showSamplingError(_ message: String) {
        loadViewIfNeeded()
        totalLabel.stringValue = "CPU unavailable"
        sampleLabel.stringValue = message
        unavailableLabel.stringValue = ""
        groups = []
        outline.reloadData()
        updateActions()
    }

    private func apply(_ incoming: [ProcessGroup]) {
        let selectedKey = selectionKey()
        let expanded = Set(groups.filter { outline.isItemExpanded($0) }.map { $0.group.id })
        let oldStructure = groups.map { ($0.group.id, $0.children.map { $0.process.identity }) }
        let structureChanged = oldStructure.count != incoming.count || zip(oldStructure, incoming).contains {
            $0.0.0 != $0.1.id || $0.0.1 != $0.1.processes.map(\.identity)
        }
        var existing = Dictionary(uniqueKeysWithValues: groups.map { ($0.group.id, $0) })
        groups = incoming.map { group in
            guard let row = existing.removeValue(forKey: group.id) else { return GroupRow(group) }
            let children = Dictionary(uniqueKeysWithValues: row.children.map { ($0.process.identity, $0) })
            row.group = group
            row.children = group.processes.map { process in
                let child = children[process.identity] ?? ProcessRow(process)
                child.process = process
                return child
            }
            return row
        }
        if structureChanged {
            outline.reloadData()
            for row in groups where expanded.contains(row.group.id) { outline.expandItem(row) }
            if let selectedKey,
               let row = (0..<outline.numberOfRows).first(where: { key(outline.item(atRow: $0)) == selectedKey }) {
                outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else {
                outline.deselectAll(nil)
            }
        } else {
            for row in 0..<outline.numberOfRows {
                for column in 0..<outline.numberOfColumns {
                    if let cell = outline.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                        configure(cell, item: outline.item(atRow: row), column: column)
                    }
                }
            }
        }
    }

    private func key(_ item: Any?) -> String? {
        if let group = item as? GroupRow { return "group:\(group.group.id)" }
        if let process = item as? ProcessRow {
            return "process:\(process.process.pid):\(process.process.identity.startTimeMicroseconds)"
        }
        return nil
    }

    private func selectionKey() -> String? {
        guard outline.selectedRow >= 0 else { return nil }
        return key(outline.item(atRow: outline.selectedRow))
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? GroupRow)?.children.count ?? (item == nil ? groups.count : 0)
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let group = item as? GroupRow { return group.children[index] }
        return groups[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? GroupRow)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = tableColumn.identifier
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        configure(cell, item: item, column: identifier.rawValue == "cpu" ? 1 : 0)
        return cell
    }

    private func configure(_ cell: NSTableCellView, item: Any?, column: Int) {
        let name: String
        let percent: Double
        let readingAvailable: Bool
        let tooltip: String
        if let group = item as? GroupRow {
            name = group.group.name
            percent = group.group.cpuPercent
            readingAvailable = processesReady && group.group.processes.contains(where: \.cpuReadingAvailable)
            let missing = group.group.processes.filter { !$0.cpuReadingAvailable }.count
            tooltip = "\(name), \(group.children.count) processes\(missing > 0 ? ", \(missing) CPU readings unavailable" : "")"
        } else if let row = item as? ProcessRow {
            name = "\(row.process.name) (\(row.process.pid))"
            percent = row.process.cpuPercent
            readingAvailable = processesReady && row.process.cpuReadingAvailable
            tooltip = "\(row.process.executablePath)\n\(row.process.terminationRestriction ?? "Can request quit or force quit")"
        } else { return }
        cell.textField?.stringValue = column == 0 ? name
            : (readingAvailable ? "\(percent.formatted(.number.precision(.fractionLength(1))))%" : (processesReady ? "?" : "Wait"))
        cell.textField?.alignment = column == 0 ? .left : .right
        cell.textField?.font = column == 0 ? .systemFont(ofSize: 12)
            : .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        cell.toolTip = readingAvailable ? tooltip : "\(tooltip)\n\(processesReady ? "CPU reading unavailable." : "Measuring CPU usage.")"
        cell.textField?.setAccessibilityLabel(column == 0 ? name : "\(name), \(readingAvailable ? "\(percent.formatted(.number.precision(.fractionLength(1)))) percent CPU" : "CPU reading unavailable")")
    }

    func outlineViewSelectionDidChange(_ notification: Notification) { updateActions() }

    private func updateActions() {
        let item = outline.selectedRow >= 0 ? outline.item(atRow: outline.selectedRow) : nil
        let eligible = (item as? GroupRow)?.group.canTerminate ?? (item as? ProcessRow)?.process.canTerminate ?? false
        quitButton.isEnabled = eligible && !terminating
        forceQuitButton.isEnabled = eligible && !terminating
    }

    @objc private func showSettings(_ sender: Any?) { onSettings?() }
    @objc private func checkUpdates(_ sender: Any?) { updates.checkForUpdates() }

    private func refreshUpdates() {
        updateButton.title = updates.availableVersion.map { "Update \($0)…" } ?? "Check for Updates…"
        updateButton.isEnabled = updates.canCheckForUpdates
        updateButton.toolTip = updates.statusText
    }

    private func observeUpdates() {
        withObservationTracking {
            _ = updates.availableVersion
            _ = updates.canCheckForUpdates
            _ = updates.statusText
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshUpdates()
                self?.observeUpdates()
            }
        }
    }
    @objc private func quitSelected(_ sender: Any?) { confirmTermination(.quit) }
    @objc private func forceQuitSelected(_ sender: Any?) { confirmTermination(.forceQuit) }

    private func confirmTermination(_ mode: TerminationMode) {
        guard outline.selectedRow >= 0 else { return }
        let item = outline.item(atRow: outline.selectedRow)
        let group = (item as? GroupRow)?.group
        let process = (item as? ProcessRow)?.process
        guard group?.canTerminate == true || process?.canTerminate == true else { return }
        let force = mode == .forceQuit
        let verb = force ? "Force Quit" : "Quit"
        let name = group?.name ?? process?.name ?? "Process"
        let alert = NSAlert()
        alert.messageText = "\(verb) \(name)?"
        if let group {
            let identities = group.processes.prefix(5).map { "\($0.name) (PID \($0.pid))" }.joined(separator: ", ")
            let remaining = group.processes.count - 5
            let summary = identities + (remaining > 0 ? ", and \(remaining) others" : "")
            alert.informativeText = "This will \(force ? "immediately stop" : "ask to stop") all \(group.processes.count) processes in \(group.name): \(summary). Unsaved work may be lost."
        } else if let process {
            alert.informativeText = "This will \(force ? "immediately stop" : "ask to stop") \(process.name), PID \(process.pid). Unsaved work may be lost."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: verb)
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        alert.buttons[1].hasDestructiveAction = true
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        terminating = true
        updateActions()
        Task {
            do {
                if let process { try await terminator.terminate(process, mode: mode) }
                else if let group { try await terminator.terminate(group, mode: mode) }
            } catch {
                let failure = NSAlert()
                failure.messageText = "Could not \(verb.lowercased()) \(name)"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
            terminating = false
            updateActions()
        }
    }
}
