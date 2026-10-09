import Foundation

public struct ProcessIdentity: Hashable, Sendable {
    public let pid: Int32
    public let uid: UInt32
    public let startTimeMicroseconds: UInt64

    public init(pid: Int32, uid: UInt32, startTimeMicroseconds: UInt64) {
        self.pid = pid
        self.uid = uid
        self.startTimeMicroseconds = startTimeMicroseconds
    }
}

public struct ProcessSample: Identifiable, Sendable {
    public var id: ProcessIdentity { identity }
    public let identity: ProcessIdentity
    public var pid: Int32 { identity.pid }
    public var uid: UInt32 { identity.uid }
    public let parentPID: Int32
    public let name: String
    public let executablePath: String
    public let cpuPercent: Double
    public let residentMemoryBytes: UInt64
    public let cpuReadingAvailable: Bool
    public let terminationRestriction: String?
    public var canTerminate: Bool { terminationRestriction == nil }

    public init(identity: ProcessIdentity, parentPID: Int32, name: String, executablePath: String,
                cpuPercent: Double, residentMemoryBytes: UInt64, terminationRestriction: String?,
                cpuReadingAvailable: Bool = true) {
        self.identity = identity
        self.parentPID = parentPID
        self.name = name
        self.executablePath = executablePath
        self.cpuPercent = cpuPercent
        self.residentMemoryBytes = residentMemoryBytes
        self.cpuReadingAvailable = cpuReadingAvailable
        self.terminationRestriction = terminationRestriction
    }
}

public struct ProcessGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let cpuPercent: Double
    public let residentMemoryBytes: UInt64
    public let processes: [ProcessSample]
    public var canTerminate: Bool { !processes.isEmpty && processes.allSatisfy(\.canTerminate) }

    public init(id: String, name: String, processes: [ProcessSample]) {
        self.id = id
        self.name = name
        self.processes = processes
        self.cpuPercent = processes.reduce(0) { $0 + $1.cpuPercent }
        self.residentMemoryBytes = processes.reduce(0) { $0 + $1.residentMemoryBytes }
    }
}

public struct SamplingSnapshot: Sendable {
    public let timestamp: Date
    public let systemCPUPercent: Double
    /// Per-core capacity in Mach processor order. Nil until a valid interval is available.
    public let coreCPUPercentages: [Double]?
    public let logicalProcessorCount: Int
    public let includesProcesses: Bool
    public let groups: [ProcessGroup]
    public let unavailableProcessCount: Int
}

public enum TerminationMode: Sendable {
    case quit
    case forceQuit
}

public enum ProcessCoreError: LocalizedError, Sendable {
    case samplingFailed(String)
    case processUnavailable(Int32)
    case identityChanged(Int32)
    case terminationRestricted(Int32, String)
    case signalFailed(Int32, Int32)

    public var errorDescription: String? {
        switch self {
        case .samplingFailed(let reason): return "CPU sampling failed: \(reason)."
        case .processUnavailable(let pid): return "Process \(pid) has exited or cannot be inspected."
        case .identityChanged(let pid): return "Process \(pid) changed since it was selected. Refresh the list."
        case .terminationRestricted(let pid, let reason): return "Cannot stop process \(pid): \(reason)."
        case .signalFailed(let pid, let code): return "Could not stop process \(pid) (system error \(code))."
        }
    }
}
