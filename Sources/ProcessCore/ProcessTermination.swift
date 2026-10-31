import Darwin
import Foundation

enum TerminationPolicy {
    static func restriction(identity: ProcessIdentity, realUID: UInt32, path: String,
                            currentUID: UInt32, currentPID: Int32, ancestors: Set<Int32>) -> String? {
        if identity.pid <= 1 || identity.uid == 0 { return "system process" }
        if identity.uid != currentUID || realUID != currentUID { return "process belongs to another user" }
        if identity.pid == currentPID { return "this utility" }
        if ancestors.contains(identity.pid) { return "process started this utility" }
        if path.isEmpty { return "executable identity is unavailable" }
        if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/") { return "protected system process" }
        return nil
    }

    static func validate(expected: ProcessIdentity, actual: ProcessIdentity) throws {
        guard expected == actual else { throw ProcessCoreError.identityChanged(expected.pid) }
    }
}

public actor ProcessTerminator {
    public init() {}

    public func terminate(_ process: ProcessSample, mode: TerminationMode) throws {
        try validate(process)
        try signal(process, mode: mode)
    }

    public func terminate(_ group: ProcessGroup, mode: TerminationMode) throws {
        guard !group.processes.isEmpty else { return }
        for process in group.processes { try validate(process) }
        let selected = Set(group.processes.map(\.pid))
        let ordered = group.processes.sorted { first, second in
            func depth(_ process: ProcessSample) -> Int {
                var parent = process.parentPID
                var visited: Set<Int32> = []
                while selected.contains(parent), visited.insert(parent).inserted,
                      let record = group.processes.first(where: { $0.pid == parent }) { parent = record.parentPID }
                return visited.count
            }
            return depth(first) > depth(second)
        }
        for process in ordered { try signal(process, mode: mode) }
    }

    private func validate(_ process: ProcessSample) throws {
        guard let info = NativeProcessReader.bsdInfo(process.pid) else {
            throw ProcessCoreError.processUnavailable(process.pid)
        }
        let actual = NativeProcessReader.identity(info)
        try TerminationPolicy.validate(expected: process.identity, actual: actual)
        let restriction = TerminationPolicy.restriction(identity: actual, realUID: info.pbi_ruid,
            path: NativeProcessReader.executablePath(process.pid), currentUID: getuid(), currentPID: getpid(),
            ancestors: NativeProcessReader.ancestorIDs(of: getpid()))
        if let restriction { throw ProcessCoreError.terminationRestricted(process.pid, restriction) }
    }

    private func signal(_ process: ProcessSample, mode: TerminationMode) throws {
        try validate(process)
        guard let latest = NativeProcessReader.bsdInfo(process.pid) else {
            throw ProcessCoreError.processUnavailable(process.pid)
        }
        try TerminationPolicy.validate(expected: process.identity, actual: NativeProcessReader.identity(latest))
        guard latest.pbi_ruid == getuid() else {
            throw ProcessCoreError.terminationRestricted(process.pid, "process belongs to another user")
        }
        let code = mode == .quit ? SIGTERM : SIGKILL
        guard Darwin.kill(process.pid, code) == 0 else { throw ProcessCoreError.signalFailed(process.pid, errno) }
    }
}
