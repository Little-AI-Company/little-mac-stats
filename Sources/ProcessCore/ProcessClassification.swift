enum ProcessClassification {
    private static let claudeVersionsDirectory = [".local", "share", "claude", "versions"]

    struct Attribution: Hashable {
        let id: String
        let name: String
    }

    struct ExecutableClassification {
        let application: Attribution?
        let tool: Attribution?
        let name: String
    }

    static func executable(for path: String) -> ExecutableClassification {
        let components = path.split(separator: "/")
        let name = components.last.map(String.init) ?? ""
        var application: Attribution?
        if let index = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let bundle = "/" + components[...index].joined(separator: "/")
            application = Attribution(id: "application:\(bundle)", name: String(components[index].dropLast(4)))
        }
        var tool: Attribution?
        if let application {
            switch application.name.lowercased() {
            case "codex": tool = Attribution(id: "tool:codex", name: "Codex")
            case "claude": tool = Attribution(id: "tool:claude", name: "Claude")
            case "cursor": tool = Attribution(id: "tool:cursor", name: "Cursor")
            case "windsurf": tool = Attribution(id: "tool:windsurf", name: "Windsurf")
            default: break
            }
        }
        if tool == nil && components.contains("Codex Framework.framework") {
            tool = Attribution(id: "tool:codex", name: "Codex")
        }
        if tool == nil, components.dropLast().suffix(4).map(String.init) == claudeVersionsDirectory {
            let numbers = name.split(separator: ".", omittingEmptySubsequences: false)
            if numbers.count == 3 && numbers.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
                tool = Attribution(id: "tool:claude", name: "Claude")
            }
        }
        if tool == nil {
            switch name.lowercased() {
            case "codex": tool = Attribution(id: "tool:codex", name: "Codex")
            case "claude": tool = Attribution(id: "tool:claude", name: "Claude")
            case "aider": tool = Attribution(id: "tool:aider", name: "Aider")
            case "opencode": tool = Attribution(id: "tool:opencode", name: "OpenCode")
            case "goose": tool = Attribution(id: "tool:goose", name: "Goose")
            default: break
            }
        }
        return ExecutableClassification(application: application, tool: tool, name: name)
    }

    static func executables(for records: [NativeProcess]) -> [String: ExecutableClassification] {
        var result: [String: ExecutableClassification] = [:]
        result.reserveCapacity(records.count)
        for record in records where result[record.executablePath] == nil {
            result[record.executablePath] = executable(for: record.executablePath)
        }
        return result
    }

    static func tool(for path: String, applicationTools: [String: Attribution] = [:]) -> Attribution? {
        let classification = executable(for: path)
        if let application = classification.application, let tool = applicationTools[application.id] { return tool }
        return classification.tool
    }

    static func attribution(for process: NativeProcess, byPID: [Int32: NativeProcess],
                            applicationTools: [String: Attribution] = [:]) -> Attribution {
        var records = byPID
        records[process.identity.pid] = process
        var resolver = AttributionResolver(byPID: records, executables: executables(for: Array(records.values)),
                                           applicationTools: applicationTools)
        return resolver.attribution(for: process)
    }

    static func groups(records: [NativeProcess], samples: [ProcessIdentity: ProcessSample],
                       applicationTools: [String: Attribution] = [:],
                       executables: [String: ExecutableClassification]? = nil) -> [ProcessGroup] {
        let byPID = Dictionary(records.map { ($0.identity.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var resolver = AttributionResolver(byPID: byPID, executables: executables ?? self.executables(for: records),
                                           applicationTools: applicationTools)
        var grouped: [Attribution: [ProcessSample]] = [:]
        for record in records {
            guard let sample = samples[record.identity] else { continue }
            grouped[resolver.attribution(for: record), default: []].append(sample)
        }
        return grouped.map { attribution, processes in
            ProcessGroup(id: attribution.id, name: attribution.name,
                         processes: processes.sorted { $0.cpuPercent == $1.cpuPercent ? $0.pid < $1.pid : $0.cpuPercent > $1.cpuPercent })
        }.sorted { $0.cpuPercent == $1.cpuPercent ? $0.id < $1.id : $0.cpuPercent > $1.cpuPercent }
    }

    private struct AttributionResolver {
        struct Resolution {
            let tool: Attribution?
            let application: Attribution?
        }

        let byPID: [Int32: NativeProcess]
        let executables: [String: ExecutableClassification]
        let applicationTools: [String: Attribution]
        var resolved: [Int32: Resolution] = [:]
        var visiting: Set<Int32> = []

        mutating func attribution(for process: NativeProcess) -> Attribution {
            let resolution = resolve(process)
            if let tool = resolution.tool { return tool }
            if let application = resolution.application { return application }
            let name = process.executablePath.isEmpty ? process.name : executables[process.executablePath]?.name ?? process.name
            return Attribution(id: "process:\(process.identity.pid):\(process.identity.startTimeMicroseconds)",
                               name: name.isEmpty ? "Process \(process.identity.pid)" : name)
        }

        mutating func resolve(_ process: NativeProcess) -> Resolution {
            let pid = process.identity.pid
            if let resolution = resolved[pid] { return resolution }
            guard visiting.insert(pid).inserted else { return Resolution(tool: nil, application: nil) }
            defer { visiting.remove(pid) }
            let executable = executables[process.executablePath]
            let application = executable?.application
            let ownTool = application.flatMap { applicationTools[$0.id] } ?? executable?.tool
            let resolution: Resolution
            if let ownTool {
                resolution = Resolution(tool: ownTool, application: application)
            } else if let parent = byPID[process.parentPID], parent.identity.uid == process.identity.uid,
                      parent.identity.startTimeMicroseconds <= process.identity.startTimeMicroseconds {
                let inherited = resolve(parent)
                resolution = Resolution(tool: inherited.tool, application: application ?? inherited.application)
            } else {
                resolution = Resolution(tool: nil, application: application)
            }
            resolved[pid] = resolution
            return resolution
        }
    }
}
