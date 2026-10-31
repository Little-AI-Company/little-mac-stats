import Darwin
import Foundation
import Testing
@testable import ProcessCore

@Test func processCPUUsesWholeMachineCapacity() {
    #expect(CPUCalculation.processPercent(previous: 100, current: 1_000_000_100,
        elapsedNanoseconds: 1_000_000_000, processorCount: 8) == 12.5)
    #expect(CPUCalculation.processPercent(previous: 2, current: 1, elapsedNanoseconds: 100, processorCount: 8) == 0)
    #expect(CPUCalculation.processPercent(previous: 0, current: 10, elapsedNanoseconds: 0, processorCount: 8) == 0)
    #expect(CPUCalculation.processPercent(previous: 100, current: 24_000_100,
        elapsedNanoseconds: 1_000_000_000, processorCount: 8, nanosecondsPerTick: 125.0 / 3.0) == 12.5)
    #expect(CPUCalculation.processPercent(previous: UInt64.max - 24_000_000, current: UInt64.max,
        elapsedNanoseconds: 1_000_000_000, processorCount: 8, nanosecondsPerTick: 125.0 / 3.0) == 12.5)
}

@Test func coreCPUUsesEachCoresOwnCapacityInProcessorOrder() {
    let previous: [[UInt32]] = [[10, 20, 30, 0], [10, 0, 40, 0], [10, 20, 30, 0]]
    let current: [[UInt32]] = [[20, 30, 30, 0], [10, 0, 60, 0], [20, 30, 60, 0]]
    #expect(CPUCalculation.corePercentages(previous: previous, current: current) == [100, 0, 40])
    #expect(CPUCalculation.corePercentages(previous: [[UInt32.max - 1, 0, 10, 0]],
                                         current: [[3, 0, 15, 0]]) == [50])
}

@Test func coreCPURequiresAValidBaselineAndUnchangedProcessorCount() {
    let ticks: [[UInt32]] = [[10, 20, 30, 0], [40, 50, 60, 0]]
    #expect(CPUCalculation.corePercentages(previous: nil, current: ticks) == nil)
    #expect(CPUCalculation.corePercentages(previous: ticks, current: [ticks[0]]) == nil)
    #expect(CPUCalculation.corePercentages(previous: [], current: []) == nil)
    #expect(CPUCalculation.corePercentages(previous: ticks, current: ticks) == nil)
    #expect(CPUCalculation.corePercentages(previous: [[1, 2, 3]], current: [[2, 3, 4]]) == nil)
}

@Test func liveClosedSamplingReportsEveryCoreAndResetClearsTheBaseline() async throws {
    let sampler = ProcessSampler()
    let first = try await sampler.sample(includeProcesses: false)
    #expect(first.coreCPUPercentages == nil)
    try await Task.sleep(for: .milliseconds(100))
    let next = try await sampler.sample(includeProcesses: false)
    let cores = try #require(next.coreCPUPercentages)
    #expect(cores.count == next.logicalProcessorCount)
    #expect(cores.count == ProcessInfo.processInfo.activeProcessorCount)
    #expect(cores.allSatisfy { $0.isFinite && (0...100).contains($0) })
    #expect(!next.includesProcesses)
    #expect(next.groups.isEmpty)
    #expect(next.unavailableProcessCount == 0)
    await sampler.reset()
    let reset = try await sampler.sample(includeProcesses: false)
    #expect(reset.coreCPUPercentages == nil)
}

@Test func descendantsBelongToOneResponsibleTool() {
    let codex = fixture(pid: 101, parent: 1, path: "/opt/bin/codex", cpu: 1)
    let shell = fixture(pid: 102, parent: 101, path: "/bin/zsh", cpu: 2)
    let compiler = fixture(pid: 103, parent: 102, path: "/usr/bin/clang", cpu: 3)
    let unrelated = fixture(pid: 104, parent: 1, path: "/usr/bin/python3", cpu: 4)
    let records = [codex, shell, compiler, unrelated]
    let samples = Dictionary(uniqueKeysWithValues: records.map { ($0.identity, sample($0)) })
    let groups = ProcessClassification.groups(records: records, samples: samples)
    let group = groups.first { $0.id == "tool:codex" }
    #expect(group?.processes.count == 3)
    #expect(group?.cpuPercent == 6)
    #expect(groups.flatMap(\.processes).count == records.count)
    #expect(groups.reduce(0) { $0 + $1.cpuPercent } == 10)
}

@Test func helpersGroupUnderOuterApplicationAndCodexBundleIdentity() {
    let helper = fixture(pid: 101, parent: 1,
        path: "/Applications/Example.app/Contents/Frameworks/Example Helper.app/Contents/MacOS/Example Helper", cpu: 1)
    #expect(ProcessClassification.attribution(for: helper, byPID: [:]).name == "Example")
    let codex = fixture(pid: 102, parent: 1, path: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT", cpu: 1)
    let mapping: [String: ProcessClassification.Attribution] = ["application:/Applications/ChatGPT.app": .init(id: "tool:codex", name: "Codex")]
    #expect(ProcessClassification.attribution(for: codex, byPID: [:], applicationTools: mapping).name == "Codex")
    #expect(ProcessClassification.tool(for: "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Helpers/worker")?.name == "Codex")
}

@Test func unrelatedNamesAndReusedParentsDoNotClaimToolAttribution() {
    #expect(ProcessClassification.tool(for: "/usr/bin/claude-backup") == nil)
    #expect(ProcessClassification.tool(for: "/System/Library/CursorUIViewService") == nil)
    #expect(ProcessClassification.tool(for: "/Users/test/codex-project/python3") == nil)
    #expect(ProcessClassification.tool(for: "/Users/test/.local/share/claude/versions/2.1.295")?.name == "Claude")
    #expect(ProcessClassification.tool(for: "/Users/test/.local/share/claude/versions/project-backup") == nil)
    let process = fixture(pid: 102, parent: 101, path: "/usr/bin/python3", cpu: 1)
    let parent = fixture(pid: 101, parent: 1, path: "/opt/bin/codex", cpu: 0, start: 900)
    #expect(ProcessClassification.attribution(for: process, byPID: [101: parent]).name == "python3")
    let otherUser = fixture(pid: 101, parent: 1, path: "/opt/bin/claude", cpu: 0, uid: 777)
    #expect(ProcessClassification.attribution(for: process, byPID: [101: otherUser]).name == "python3")
}

@Test func sharedAncestorResolutionPreservesNearestApplicationAndToolPriority() {
    let parent = fixture(pid: 101, parent: 1, path: "/Applications/Terminal.app/Contents/MacOS/Terminal", cpu: 1)
    let first = fixture(pid: 102, parent: 101, path: "/Applications/First.app/Contents/MacOS/First", cpu: 2)
    let second = fixture(pid: 103, parent: 101, path: "/Applications/Second.app/Contents/MacOS/Second", cpu: 3)
    let compiler = fixture(pid: 104, parent: 102, path: "/usr/bin/clang", cpu: 4)
    let records = [parent, first, second, compiler]
    let samples = Dictionary(uniqueKeysWithValues: records.map { ($0.identity, sample($0)) })
    let groups = ProcessClassification.groups(records: records, samples: samples)
    #expect(groups.first { $0.name == "First" }?.cpuPercent == 6)
    #expect(groups.first { $0.name == "Second" }?.cpuPercent == 3)
    #expect(groups.first { $0.name == "Terminal" }?.cpuPercent == 1)

    let codex = fixture(pid: 101, parent: 1, path: "/opt/bin/codex", cpu: 1)
    let toolGroups = ProcessClassification.groups(records: [codex, first, second, compiler], samples: samples)
    #expect(toolGroups.count == 1)
    #expect(toolGroups.first?.name == "Codex")
    #expect(toolGroups.first?.cpuPercent == 10)
}

@Test func executableChangesWithSameStartIdentityRefreshClassification() {
    let before = fixture(pid: 101, parent: 1, path: "/opt/bin/codex", cpu: 1)
    let after = fixture(pid: 101, parent: 1, path: "/usr/bin/python3", cpu: 1)
    let child = fixture(pid: 102, parent: 101, path: "/bin/zsh", cpu: 2)
    let samples = Dictionary(uniqueKeysWithValues: [before, child].map { ($0.identity, sample($0)) })
    #expect(ProcessClassification.groups(records: [before, child], samples: samples).count == 1)
    let refreshed = ProcessClassification.groups(records: [after, child], samples: samples)
    #expect(refreshed.count == 2)
    #expect(!refreshed.contains { $0.name == "Codex" })
}

@Test func terminationRejectsReusedPIDAndProtectedProcesses() throws {
    let expected = ProcessIdentity(pid: 200, uid: 501, startTimeMicroseconds: 100)
    #expect(throws: ProcessCoreError.self) {
        try TerminationPolicy.validate(expected: expected, actual: .init(pid: 200, uid: 501, startTimeMicroseconds: 101))
    }
    #expect(throws: ProcessCoreError.self) {
        try TerminationPolicy.validate(expected: expected, actual: .init(pid: 200, uid: 502, startTimeMicroseconds: 100))
    }
    #expect(TerminationPolicy.restriction(identity: expected, realUID: 501, path: "/bin/sleep",
        currentUID: 501, currentPID: 999, ancestors: []) == nil)
    #expect(TerminationPolicy.restriction(identity: expected, realUID: 501, path: "/bin/sleep",
        currentUID: 501, currentPID: 200, ancestors: []) != nil)
    #expect(TerminationPolicy.restriction(identity: expected, realUID: 501, path: "/bin/sleep",
        currentUID: 501, currentPID: 999, ancestors: [200]) != nil)
    #expect(TerminationPolicy.restriction(identity: expected, realUID: 502, path: "/bin/sleep",
        currentUID: 501, currentPID: 999, ancestors: []) != nil)
    #expect(TerminationPolicy.restriction(identity: expected, realUID: 501, path: "/System/Library/worker",
        currentUID: 501, currentPID: 999, ancestors: []) != nil)
    #expect(TerminationPolicy.restriction(identity: .init(pid: 200, uid: 0, startTimeMicroseconds: 100),
        realUID: 0, path: "/bin/sleep", currentUID: 0, currentPID: 999, ancestors: []) != nil)
}

@Test func realDisposableProcessRequiresCurrentIdentityBeforeTermination() async throws {
    let fixture = Process()
    fixture.executableURL = URL(fileURLWithPath: "/bin/sleep")
    fixture.arguments = ["60"]
    try fixture.run()
    defer {
        if fixture.isRunning { fixture.terminate() }
        fixture.waitUntilExit()
    }
    let sampler = ProcessSampler()
    let snapshot = try await sampler.sample(includeProcesses: true)
    let process = try #require(snapshot.groups.flatMap(\.processes).first { $0.pid == fixture.processIdentifier })
    let stale = ProcessSample(identity: .init(pid: process.pid, uid: process.uid,
        startTimeMicroseconds: process.identity.startTimeMicroseconds + 1), parentPID: process.parentPID,
        name: process.name, executablePath: process.executablePath, cpuPercent: 0,
        residentMemoryBytes: 0, terminationRestriction: nil)
    let terminator = ProcessTerminator()
    await #expect(throws: ProcessCoreError.self) { try await terminator.terminate(stale, mode: .quit) }
    #expect(fixture.isRunning)
    try await terminator.terminate(process, mode: .quit)
    fixture.waitUntilExit()
    #expect(fixture.terminationReason == .uncaughtSignal)
    #expect(fixture.terminationStatus == SIGTERM)
}

private func fixture(pid: Int32, parent: Int32, path: String, cpu: UInt64,
                     uid: UInt32 = 501, start: UInt64 = 100) -> NativeProcess {
    NativeProcess(identity: .init(pid: pid, uid: uid, startTimeMicroseconds: start), parentPID: parent,
        realUID: uid, name: URL(fileURLWithPath: path).lastPathComponent, executablePath: path,
        cpuTicks: cpu, residentMemoryBytes: 1)
}

private func sample(_ record: NativeProcess) -> ProcessSample {
    ProcessSample(identity: record.identity, parentPID: record.parentPID, name: record.name,
        executablePath: record.executablePath, cpuPercent: Double(record.cpuTicks ?? 0),
        residentMemoryBytes: record.residentMemoryBytes, terminationRestriction: nil)
}
