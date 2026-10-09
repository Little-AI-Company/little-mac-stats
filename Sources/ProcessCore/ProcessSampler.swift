import Darwin
import Foundation

public actor ProcessSampler {
    private var previousTicks: [UInt32]?
    private var previousProcesses: [ProcessIdentity: UInt64] = [:]
    private var previousProcessTime: UInt64?
    private let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
    private let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(max(1, timebase.denom))
    }()
    private var inspectedApplications: Set<String> = []
    private var applicationTools: [String: ProcessClassification.Attribution] = [:]

    public init() {}

    public func reset() {
        previousTicks = nil
        previousProcesses = [:]
        previousProcessTime = nil
    }

    public func sample(includeProcesses: Bool) throws -> SamplingSnapshot {
        let ticks = try NativeProcessReader.hostTicks()
        let total = previousTicks.map { CPUCalculation.systemPercent(previous: $0, current: ticks) } ?? 0
        previousTicks = ticks
        var groups: [ProcessGroup] = []
        var unavailableProcessCount = 0
        if includeProcesses {
            let now = DispatchTime.now().uptimeNanoseconds
            let elapsed = previousProcessTime.map { now >= $0 ? now - $0 : 0 } ?? 0
            let identifiers = try NativeProcessReader.processIDs()
            let records = identifiers.compactMap(NativeProcessReader.read)
            unavailableProcessCount = identifiers.count - records.count + records.filter { $0.cpuTicks == nil }.count
            for record in records {
                guard let application = ProcessClassification.application(for: record.executablePath),
                      inspectedApplications.insert(application.id).inserted else { continue }
                let path = String(application.id.dropFirst("application:".count))
                switch Bundle(path: path)?.bundleIdentifier {
                case "com.openai.codex":
                    applicationTools[application.id] = .init(id: "tool:codex", name: "Codex")
                case "com.anthropic.claudefordesktop":
                    applicationTools[application.id] = .init(id: "tool:claude", name: "Claude")
                default: break
                }
            }
            let ancestors = NativeProcessReader.ancestorIDs(of: getpid())
            var samples: [ProcessIdentity: ProcessSample] = [:]
            var counters: [ProcessIdentity: UInt64] = [:]
            for record in records {
                var percent = 0.0
                if let counter = record.cpuTicks {
                    if let previous = previousProcesses[record.identity] {
                        percent = CPUCalculation.processPercent(previous: previous, current: counter,
                            elapsedNanoseconds: elapsed, processorCount: processorCount,
                            nanosecondsPerTick: nanosecondsPerTick)
                    }
                    counters[record.identity] = counter
                }
                let restriction = TerminationPolicy.restriction(identity: record.identity, realUID: record.realUID,
                    path: record.executablePath, currentUID: getuid(), currentPID: getpid(), ancestors: ancestors)
                samples[record.identity] = ProcessSample(identity: record.identity, parentPID: record.parentPID,
                    name: record.name, executablePath: record.executablePath, cpuPercent: percent,
                    residentMemoryBytes: record.residentMemoryBytes, terminationRestriction: restriction,
                    cpuReadingAvailable: record.cpuTicks != nil)
            }
            groups = ProcessClassification.groups(records: records, samples: samples, applicationTools: applicationTools)
            previousProcesses = counters
            previousProcessTime = now
        } else {
            previousProcesses = [:]
            previousProcessTime = nil
        }
        return SamplingSnapshot(timestamp: Date(), systemCPUPercent: total, logicalProcessorCount: processorCount,
                                includesProcesses: includeProcesses, groups: groups,
                                unavailableProcessCount: unavailableProcessCount)
    }
}
