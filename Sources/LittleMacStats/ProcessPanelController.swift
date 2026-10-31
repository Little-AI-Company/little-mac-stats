import AppKit
import Observation
import ProcessCore

@MainActor
private final class GroupRow: NSObject {
    var group: ProcessGroup {
        didSet {
            if group.name != oldValue.name { searchQuery = nil }
        }
    }
    var children: [ProcessRow]
    var visibleChildren: [ProcessRow]
    var searchQuery: String?
    var matchesSearch = false
    init(_ group: ProcessGroup) {
        self.group = group
        children = group.processes.map(ProcessRow.init)
        visibleChildren = children
    }
}

@MainActor
private final class ProcessRow: NSObject {
    var process: ProcessSample {
        didSet {
            if process.name != oldValue.name || process.executablePath != oldValue.executablePath {
                searchQuery = nil
            }
        }
    }
    var searchQuery: String?
    var matchesSearch = false
    init(_ process: ProcessSample) { self.process = process }
}

@MainActor
private final class ProcessOutlineView: NSOutlineView {
    var onClose: (() -> Void)?
    var onInteraction: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        onInteraction?()
        if event.keyCode == 53 { onClose?() } else { super.keyDown(with: event) }
    }
    override func mouseDown(with event: NSEvent) {
        onInteraction?()
        super.mouseDown(with: event)
    }
    override func scrollWheel(with event: NSEvent) {
        onInteraction?()
        super.scrollWheel(with: event)
    }
}

@MainActor
final class ProcessPanelController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate {
    var onSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var onClose: (() -> Void)?
    var onDisplayStyleChange: ((StatusDisplayStyle) -> Void)?
    var displayStyle: StatusDisplayStyle = .coreBlocks {
        didSet {
            if isViewLoaded { synchronizeDisplayChoices() }
        }
    }
    private let terminator: ProcessTerminator
    private let updates: UpdateController
    private let updateButton = NSButton(title: "Check for Updates…", target: nil, action: nil)
    private var displayChoiceButtons: [StatusDisplayStyle: NSButton] = [:]
    private let totalLabel = NSTextField(labelWithString: "Measuring…")
    private let sampleLabel = NSTextField(labelWithString: "Collecting a process sample…")
    private let historyView = CPUHistoryView()
    private let searchField = NSSearchField()
    private let outline = ProcessOutlineView()
    private let stopButton = NSButton(title: "Stop…", target: nil, action: nil)
    private var allGroups: [GroupRow] = []
    private var groups: [GroupRow] = []
    private var processesReady = false
    private var terminating = false
    private var lastInteraction = Date.distantPast
    private var history: [CPUHistorySample] = []
    private var latestSystemPercent: Double?
    private var latestSystemTimestamp = Date()
    private var applicationIcons: [String: NSImage] = [:]
    private var inspectedApplications: Set<String> = []
    private var applicationIdentifiers: [String: String] = [:]
    private let terminalIcon = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)

    init(terminator: ProcessTerminator, updates: UpdateController) {
        self.terminator = terminator
        self.updates = updates
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 468, height: 620)
    }
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: preferredContentSize))
        let title = NSTextField(labelWithString: "CPU Usage")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        totalLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .medium)
        totalLabel.setAccessibilityLabel("Total CPU usage")
        totalLabel.toolTip = "100% means all CPU capacity is in use."
        totalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        historyView.toolTip = "Measured CPU usage over the last \(CPUHistorySample.windowSeconds) seconds, on a fixed 0–100% scale."
        searchField.placeholderString = "Search apps and processes"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.setAccessibilityLabel("Search apps and processes")
        sampleLabel.font = .systemFont(ofSize: 11)
        sampleLabel.textColor = .secondaryLabelColor
        sampleLabel.lineBreakMode = .byTruncatingTail

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "App or Process"
        nameColumn.width = 300
        nameColumn.minWidth = 180
        nameColumn.resizingMask = .autoresizingMask
        let cpuColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cpu"))
        cpuColumn.title = "CPU"
        cpuColumn.headerToolTip = "Percent of total CPU capacity. Every bar uses the same 0–100% scale."
        cpuColumn.width = 122
        cpuColumn.minWidth = 122
        cpuColumn.maxWidth = 122
        cpuColumn.resizingMask = []
        outline.addTableColumn(nameColumn)
        outline.addTableColumn(cpuColumn)
        outline.outlineTableColumn = nameColumn
        outline.delegate = self
        outline.dataSource = self
        outline.rowHeight = 27
        outline.intercellSpacing = NSSize(width: 4, height: 0)
        outline.style = .plain
        outline.indentationPerLevel = 14
        outline.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outline.frame = NSRect(x: 0, y: 0, width: 440, height: 315)
        outline.allowsMultipleSelection = false
        outline.setAccessibilityLabel("CPU usage by app and process")
        outline.onClose = { [weak self] in self?.onClose?() }
        outline.onInteraction = { [weak self] in self?.lastInteraction = Date() }
        let scrollView = NSScrollView()
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.setAccessibilityLabel("Running apps and processes")

        stopButton.target = self
        stopButton.action = #selector(stopSelected(_:))
        stopButton.toolTip = "Choose whether to quit or force quit the selected app or process."
        let displayRows = StatusDisplayStyle.allCases.map(displayChoiceRow)
        let displayChoices = NSStackView(views: displayRows)
        displayChoices.orientation = .vertical
        displayChoices.alignment = .leading
        displayChoices.spacing = 0
        let displaySeparator = NSBox()
        displaySeparator.boxType = .separator
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        let footer = applicationFooter()
        let separator = NSBox()
        separator.boxType = .separator
        for component in [title, totalLabel, historyView, searchField, scrollView, separator, sampleLabel,
                          stopButton, displaySeparator, displayChoices, footerSeparator, footer] {
            component.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(component)
        }
        for row in displayRows {
            row.widthAnchor.constraint(equalTo: displayChoices.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            totalLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            totalLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            totalLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            historyView.leadingAnchor.constraint(equalTo: totalLabel.trailingAnchor, constant: 14),
            historyView.topAnchor.constraint(equalTo: title.topAnchor),
            historyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            historyView.heightAnchor.constraint(equalToConstant: 70),
            searchField.topAnchor.constraint(equalTo: historyView.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            separator.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sampleLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            sampleLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            sampleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stopButton.topAnchor.constraint(equalTo: sampleLabel.bottomAnchor, constant: 9),
            stopButton.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stopButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            displaySeparator.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 8),
            displaySeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            displaySeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            displayChoices.topAnchor.constraint(equalTo: displaySeparator.bottomAnchor, constant: 8),
            displayChoices.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            displayChoices.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            footerSeparator.topAnchor.constraint(equalTo: displayChoices.bottomAnchor, constant: 8),
            footerSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.topAnchor.constraint(equalTo: footerSeparator.bottomAnchor, constant: 8),
            footer.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 270),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 468)
        ])
        updateSystemDisplay()
        synchronizeDisplayChoices()
        updateActions()
        refreshUpdates()
        observeUpdates()
    }

    private func displayChoiceRow(_ style: StatusDisplayStyle) -> NSStackView {
        let preview = NSImageView()
        preview.image = style.previewImage(coreCount: ProcessInfo.processInfo.activeProcessorCount)
        preview.imageScaling = .scaleProportionallyDown
        preview.contentTintColor = .labelColor
        preview.setAccessibilityElement(false)
        preview.toolTip = "Illustration of the \(style.title) menu bar display."
        preview.widthAnchor.constraint(equalToConstant: 44).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let button = NSButton(radioButtonWithTitle: style.title, target: self, action: #selector(chooseDisplayStyle(_:)))
        button.font = .systemFont(ofSize: 13)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setAccessibilityLabel("\(style.title) menu bar display")
        button.toolTip = "Use \(style.title) in the menu bar."
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        displayChoiceButtons[style] = button
        let row = NSStackView(views: [preview, button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return row
    }

    private func synchronizeDisplayChoices() {
        for (style, button) in displayChoiceButtons {
            button.state = style == displayStyle ? .on : .off
        }
    }

    @objc private func chooseDisplayStyle(_ sender: NSButton) {
        guard let style = displayChoiceButtons.first(where: { $0.value === sender })?.key else { return }
        displayStyle = style
        onDisplayStyleChange?(style)
    }

    private func applicationFooter() -> NSStackView {
        let settings = NSButton(title: "Settings…", target: self, action: #selector(showSettings(_:)))
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        updateButton.target = self
        updateButton.action = #selector(checkUpdates(_:))
        updateButton.cell?.lineBreakMode = .byTruncatingMiddle
        updateButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let about = NSButton(title: "About", target: self, action: #selector(showAbout(_:)))
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.setAccessibilityLabel("Quit Little Mac Stats")
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = .command
        for button in [settings, updateButton, about, quit] {
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        }
        let footer = NSStackView(views: [settings, updateButton, about, quit])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 6
        return footer
    }

    func focusTable() { view.window?.makeFirstResponder(outline) }
    func focusSearch() {
        loadViewIfNeeded()
        view.window?.makeFirstResponder(searchField)
    }

    func recordSystemSample(percent: Double?, timestamp: Date) {
        let value = percent.flatMap { $0.isFinite ? max(0, min($0, 100)) : nil }
        latestSystemPercent = value
        latestSystemTimestamp = timestamp
        history.append(CPUHistorySample(timestamp: timestamp, percent: value))
        history.removeAll { timestamp.timeIntervalSince($0.timestamp) > CPUHistorySample.window }
    }

    func resetSystemHistory() {
        history = []
        latestSystemPercent = nil
    }

    private func updateSystemDisplay() {
        let text = latestSystemPercent.map { "\($0.formatted(.number.precision(.fractionLength(1))))%" } ?? "Measuring…"
        if totalLabel.stringValue != text { totalLabel.stringValue = text }
        historyView.update(samples: history, endTime: latestSystemTimestamp)
    }

    func beginMeasuring() {
        loadViewIfNeeded()
        processesReady = false
        sampleLabel.stringValue = "Measuring app usage…"
        allGroups = []
        groups = []
        outline.reloadData()
        updateSystemDisplay()
        updateActions()
    }

    func update(_ snapshot: SamplingSnapshot, systemReady: Bool, processesReady: Bool) {
        loadViewIfNeeded()
        self.processesReady = processesReady
        updateSystemDisplay()
        apply(snapshot.groups)
        if processesReady {
            let count = searchField.stringValue.isEmpty ? snapshot.groups.count : groups.count
            let text = (count == 1 ? "1 app or process" : "\(count) apps and processes")
                + (snapshot.unavailableProcessCount > 0 ? " · Some readings unavailable" : "")
            if sampleLabel.stringValue != text { sampleLabel.stringValue = text }
        } else {
            sampleLabel.stringValue = "Measuring app usage…"
        }
        let tooltip = "100% uses all CPU capacity. Groups include their child processes. \(snapshot.unavailableProcessCount) process readings unavailable; total CPU includes all work."
        if sampleLabel.toolTip != tooltip { sampleLabel.toolTip = tooltip }
        updateActions()
    }

    func showSamplingError(_ message: String) {
        loadViewIfNeeded()
        updateSystemDisplay()
        totalLabel.stringValue = "Unavailable"
        sampleLabel.stringValue = message
        allGroups = []
        groups = []
        outline.reloadData()
        updateActions()
    }

    private func apply(_ incoming: [ProcessGroup]) {
        let selectedKey = selectionKey()
        let expanded = Set(groups.filter { outline.isItemExpanded($0) }.map { $0.group.id })
        let oldStructure = visibleStructure()
        let preserveOrder = selectedKey != nil || !searchField.stringValue.isEmpty || searchField.currentEditor() != nil
            || !expanded.isEmpty || Date().timeIntervalSince(lastInteraction) < 3
        let oldOrder = allGroups.map { $0.group.id }
        var existing = Dictionary(uniqueKeysWithValues: allGroups.map { ($0.group.id, $0) })
        var rows = incoming.map { group in
            guard let row = existing.removeValue(forKey: group.id) else { return GroupRow(group) }
            let oldChildren = row.children.map { $0.process.identity }
            let children = Dictionary(uniqueKeysWithValues: row.children.map { ($0.process.identity, $0) })
            row.group = group
            row.children = group.processes.map { process in
                let child = children[process.identity] ?? ProcessRow(process)
                child.process = process
                return child
            }
            if preserveOrder {
                let positions = Dictionary(uniqueKeysWithValues: oldChildren.enumerated().map { ($0.element, $0.offset) })
                row.children.sort {
                    let left = positions[$0.process.identity] ?? Int.max
                    let right = positions[$1.process.identity] ?? Int.max
                    return left == right ? $0.process.pid < $1.process.pid : left < right
                }
            }
            return row
        }
        if preserveOrder {
            let positions = Dictionary(uniqueKeysWithValues: oldOrder.enumerated().map { ($0.element, $0.offset) })
            rows.sort {
                let left = positions[$0.group.id] ?? Int.max
                let right = positions[$1.group.id] ?? Int.max
                return left == right ? $0.group.id < $1.group.id : left < right
            }
        }
        allGroups = rows
        filterGroups()
        let structureChanged = oldStructure != visibleStructure()
        if structureChanged {
            reloadOutline(selectedKey: selectedKey, expanded: expanded)
        } else {
            let visibleRows = outline.rows(in: outline.visibleRect)
            guard visibleRows.location != NSNotFound else { return }
            for row in visibleRows.location..<min(NSMaxRange(visibleRows), outline.numberOfRows) {
                for column in 0..<outline.numberOfColumns {
                    if let cell = outline.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                        configure(cell, item: outline.item(atRow: row), column: column)
                    }
                }
            }
        }
    }

    private func visibleStructure() -> [ObjectIdentifier] {
        groups.flatMap { row in
            [ObjectIdentifier(row)] + (outline.isItemExpanded(row) ? row.visibleChildren.map(ObjectIdentifier.init) : [])
        }
    }

    private func filterGroups() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            groups = allGroups
            for row in groups { row.visibleChildren = row.children }
            return
        }
        groups = allGroups.filter { row in
            if row.searchQuery != query {
                row.searchQuery = query
                row.matchesSearch = row.group.name.localizedStandardContains(query)
            }
            row.visibleChildren = row.matchesSearch ? row.children : row.children.filter { child in
                if child.searchQuery != query {
                    child.searchQuery = query
                    child.matchesSearch = child.process.name.localizedStandardContains(query)
                        || String(child.process.pid).contains(query)
                        || child.process.executablePath.localizedStandardContains(query)
                }
                return child.matchesSearch
            }
            return row.matchesSearch || !row.visibleChildren.isEmpty
        }
    }

    private func reloadOutline(selectedKey: String?, expanded: Set<String>) {
        outline.reloadData()
        for row in groups where expanded.contains(row.group.id) || !searchField.stringValue.isEmpty {
            outline.expandItem(row)
        }
        if let selectedKey,
           let row = (0..<outline.numberOfRows).first(where: { key(outline.item(atRow: $0)) == selectedKey }) {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            outline.deselectAll(nil)
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        let selectedKey = selectionKey()
        let expanded = Set(groups.filter { outline.isItemExpanded($0) }.map { $0.group.id })
        filterGroups()
        reloadOutline(selectedKey: selectedKey, expanded: expanded)
        sampleLabel.stringValue = (groups.count == 1 ? "1 app or process" : "\(groups.count) apps and processes")
            + (groups.isEmpty ? " found" : "")
        updateActions()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: searchField))
            } else { onClose?() }
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            focusTable()
            if outline.selectedRow < 0, outline.numberOfRows > 0 {
                outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
            return true
        }
        return false
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
        (item as? GroupRow)?.visibleChildren.count ?? (item == nil ? groups.count : 0)
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let group = item as? GroupRow { return group.visibleChildren[index] }
        return groups[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? GroupRow)?.visibleChildren.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = tableColumn.identifier
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else if identifier.rawValue == "cpu" {
            cell = CPUUsageCellView()
            cell.textField?.alignment = .right
            cell.textField?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            cell = NSTableCellView()
            let imageView = NSImageView()
            let label = NSTextField(labelWithString: "")
            imageView.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingMiddle
            label.font = .systemFont(ofSize: 13)
            cell.addSubview(imageView)
            cell.addSubview(label)
            cell.imageView = imageView
            cell.textField = label
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.identifier = identifier
        configure(cell, item: item, column: identifier.rawValue == "cpu" ? 1 : 0)
        return cell
    }

    private func icon(for group: ProcessGroup) -> NSImage? {
        let path: String?
        if group.id.hasPrefix("application:") {
            path = String(group.id.dropFirst("application:".count))
        } else if group.id.hasPrefix("tool:") {
            let tool = String(group.id.dropFirst("tool:".count))
            let expectedIdentifier: String?
            switch tool {
            case "codex": expectedIdentifier = "com.openai.codex"
            case "claude": expectedIdentifier = "com.anthropic.claudefordesktop"
            default: expectedIdentifier = nil
            }
            let candidates = Set(group.processes.compactMap { process -> String? in
                let components = process.executablePath.split(separator: "/")
                guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
                return "/" + components[...index].joined(separator: "/")
            }).sorted()
            let identifierMatch = expectedIdentifier.flatMap { identifier in
                candidates.first { candidate in
                    if inspectedApplications.insert(candidate).inserted,
                       let bundleIdentifier = Bundle(path: candidate)?.bundleIdentifier {
                        applicationIdentifiers[candidate] = bundleIdentifier
                    }
                    return applicationIdentifiers[candidate] == identifier
                }
            }
            path = identifierMatch ?? candidates.first {
                URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.lowercased() == tool
            }
        } else {
            path = nil
        }
        guard let path else { return terminalIcon }
        if let image = applicationIcons[path] { return image }
        let image = autoreleasepool {
            let source = NSWorkspace.shared.icon(forFile: path)
            let size = NSSize(width: 18, height: 18)
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return source }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            source.draw(in: NSRect(x: 0, y: 0, width: 36, height: 36),
                        from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            bitmap.size = size
            let image = NSImage(size: size)
            image.addRepresentation(bitmap)
            return image
        }
        applicationIcons[path] = image
        return image
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
            if column == 0 {
                let image = icon(for: group.group)
                if cell.imageView?.image !== image { cell.imageView?.image = image }
            }
        } else if let row = item as? ProcessRow {
            name = "\(row.process.name) (\(row.process.pid))"
            percent = row.process.cpuPercent
            readingAvailable = processesReady && row.process.cpuReadingAvailable
            tooltip = "\(row.process.executablePath)\n\(row.process.terminationRestriction ?? "Can request quit or force quit")"
            if cell.imageView?.image != nil { cell.imageView?.image = nil }
        } else { return }
        let value = readingAvailable ? "\(percent.formatted(.number.precision(.fractionLength(1))))%" : (processesReady ? "?" : "Wait")
        let text = column == 0 ? name : value
        if cell.textField?.stringValue != text { cell.textField?.stringValue = text }
        (cell as? CPUUsageCellView)?.usageBar.percent = readingAvailable ? percent : nil
        let description = readingAvailable ? tooltip : "\(tooltip)\n\(processesReady ? "CPU reading unavailable." : "Measuring CPU usage.")"
        if cell.toolTip != description { cell.toolTip = description }
        let accessibilityLabel = column == 0 ? name : "\(name), \(readingAvailable ? "\(value.dropLast()) percent CPU" : "CPU reading unavailable")"
        if cell.textField?.accessibilityLabel() != accessibilityLabel {
            cell.textField?.setAccessibilityLabel(accessibilityLabel)
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) { updateActions() }

    private func updateActions() {
        let item = outline.selectedRow >= 0 ? outline.item(atRow: outline.selectedRow) : nil
        let eligible = (item as? GroupRow)?.group.canTerminate ?? (item as? ProcessRow)?.process.canTerminate ?? false
        stopButton.isEnabled = eligible && !terminating
    }

    @objc private func showSettings(_ sender: Any?) { onSettings?() }
    @objc private func showAbout(_ sender: Any?) { onAbout?() }
    @objc private func checkUpdates(_ sender: Any?) { updates.checkForUpdates() }

    private func refreshUpdates() {
        updateButton.title = updates.availableVersion.map { "Update \($0)…" } ?? "Check for Updates…"
        updateButton.isEnabled = updates.isConfigured && updates.canCheckForUpdates
        updateButton.toolTip = updates.statusText
    }

    private func observeUpdates() {
        withObservationTracking {
            _ = updates.availableVersion
            _ = updates.canCheckForUpdates
            _ = updates.statusText
            _ = updates.isConfigured
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshUpdates()
                self?.observeUpdates()
            }
        }
    }

    @objc private func stopSelected(_ sender: Any?) {
        guard outline.selectedRow >= 0 else { return }
        let item = outline.item(atRow: outline.selectedRow)
        let group = (item as? GroupRow)?.group
        let process = (item as? ProcessRow)?.process
        guard group?.canTerminate == true || process?.canTerminate == true else { return }
        let name = group?.name ?? process?.name ?? "Process"
        let alert = NSAlert()
        alert.messageText = "Stop \(name)?"
        let target: String
        if let group {
            let identities = group.processes.prefix(5).map { "\($0.name) (PID \($0.pid))" }.joined(separator: ", ")
            let remaining = group.processes.count - 5
            target = "All \(group.processes.count) processes in \(group.name): \(identities)\(remaining > 0 ? ", and \(remaining) others" : "")."
        } else if let process {
            target = "\(process.name), PID \(process.pid)."
        } else { return }
        alert.informativeText = "\(target)\n\nQuit requests a normal stop. Force Quit stops immediately. Unsaved work may be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Force Quit")
        alert.buttons[0].keyEquivalent = "\r"
        for button in alert.buttons.dropFirst() {
            button.keyEquivalent = ""
            button.hasDestructiveAction = true
        }
        let response = alert.runModal()
        let mode: TerminationMode
        switch response {
        case .alertSecondButtonReturn: mode = .quit
        case .alertThirdButtonReturn: mode = .forceQuit
        default: return
        }
        let verb = mode == .forceQuit ? "force quit" : "quit"
        terminating = true
        updateActions()
        Task {
            do {
                if let process { try await terminator.terminate(process, mode: mode) }
                else if let group { try await terminator.terminate(group, mode: mode) }
            } catch {
                let failure = NSAlert()
                failure.messageText = "Could not \(verb) \(name)"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
            terminating = false
            updateActions()
        }
    }
}
