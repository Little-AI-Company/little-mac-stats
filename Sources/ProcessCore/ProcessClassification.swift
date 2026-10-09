import Foundation

enum ProcessClassification {
    struct Attribution: Hashable {
        let id: String
        let name: String
    }

    static func application(for path: String) -> Attribution? {
        let components = path.split(separator: "/")
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let bundle = "/" + components[...index].joined(separator: "/")
        let name = String(components[index].dropLast(4))
        return Attribution(id: "application:\(bundle)", name: name)
    }

    static func tool(for path: String, applicationTools: [String: Attribution] = [:]) -> Attribution? {
        if let application = application(for: path) {
            if let tool = applicationTools[application.id] { return tool }
            switch application.name.lowercased() {
            case "codex": return Attribution(id: "tool:codex", name: "Codex")
            case "claude": return Attribution(id: "tool:claude", name: "Claude")
            case "cursor": return Attribution(id: "tool:cursor", name: "Cursor")
            case "windsurf": return Attribution(id: "tool:windsurf", name: "Windsurf")
            default: break
            }
        }
        if path.split(separator: "/").contains("Codex Framework.framework") {
            return Attribution(id: "tool:codex", name: "Codex")
        }
        // Claude's native installer resolves its symlink to a version-named executable.
        let components = path.split(separator: "/")
        if components.count >= 5,
           Array(components.suffix(5).dropLast()) == [".local", "share", "claude", "versions"],
           let version = components.last {
            let numbers = version.split(separator: ".", omittingEmptySubsequences: false)
            if numbers.count == 3 && numbers.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
                return Attribution(id: "tool:claude", name: "Claude")
            }
        }
        switch URL(fileURLWithPath: path).lastPathComponent.lowercased() {
        case "codex": return Attribution(id: "tool:codex", name: "Codex")
        case "claude": return Attribution(id: "tool:claude", name: "Claude")
        case "aider": return Attribution(id: "tool:aider", name: "Aider")
        case "opencode": return Attribution(id: "tool:opencode", name: "OpenCode")
        case "goose": return Attribution(id: "tool:goose", name: "Goose")
        default: return nil
        }
    }

    static func attribution(for process: NativeProcess, byPID: [Int32: NativeProcess],
                            applicationTools: [String: Attribution] = [:]) -> Attribution {
        var current: NativeProcess? = process
        var visited: Set<Int32> = []
        var application: Attribution?
        while let record = current, visited.insert(record.identity.pid).inserted {
            if let tool = tool(for: record.executablePath, applicationTools: applicationTools) { return tool }
            if application == nil { application = self.application(for: record.executablePath) }
            guard let parent = byPID[record.parentPID], parent.identity.uid == process.identity.uid,
                  parent.identity.startTimeMicroseconds <= record.identity.startTimeMicroseconds else { break }
            current = parent
        }
        if let application { return application }
        let path = process.executablePath
        let name = path.isEmpty ? process.name : URL(fileURLWithPath: path).lastPathComponent
        return Attribution(id: "process:\(process.identity.pid):\(process.identity.startTimeMicroseconds)",
                           name: name.isEmpty ? "Process \(process.identity.pid)" : name)
    }

    static func groups(records: [NativeProcess], samples: [ProcessIdentity: ProcessSample],
                       applicationTools: [String: Attribution] = [:]) -> [ProcessGroup] {
        let byPID = Dictionary(records.map { ($0.identity.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var grouped: [Attribution: [ProcessSample]] = [:]
        for record in records {
            guard let sample = samples[record.identity] else { continue }
            grouped[attribution(for: record, byPID: byPID, applicationTools: applicationTools), default: []].append(sample)
        }
        return grouped.map { attribution, processes in
            ProcessGroup(id: attribution.id, name: attribution.name,
                         processes: processes.sorted { $0.cpuPercent == $1.cpuPercent ? $0.pid < $1.pid : $0.cpuPercent > $1.cpuPercent })
        }.sorted { $0.cpuPercent == $1.cpuPercent ? $0.id < $1.id : $0.cpuPercent > $1.cpuPercent }
    }
}
