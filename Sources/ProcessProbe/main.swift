import Darwin
import Foundation
import ProcessCore

@main
struct ProcessProbe {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.contains("--help") {
                print("ProcessProbe [--samples 5] [--interval 1] [--limit 20] [--system-only] [--cores] [--verify-termination] [--verify-cpu]")
                return
            }
            if arguments.contains("--verify-termination") {
                try await verifyTermination()
                return
            }
            if arguments.contains("--verify-cpu") {
                try await verifyCPU()
                return
            }
            let count = try integerOption("--samples", arguments: arguments, default: 5)
            let limit = try integerOption("--limit", arguments: arguments, default: 20)
            let interval = try intervalOption(arguments)
            let sampler = ProcessSampler()
            let systemOnly = arguments.contains("--system-only")
            let includeCores = arguments.contains("--cores")
            let start = DispatchTime.now().uptimeNanoseconds
            let startCPU = ownCPUSeconds()
            for index in 0..<count {
                if index > 0 { try await Task.sleep(for: .seconds(interval)) }
                let sampleStart = DispatchTime.now().uptimeNanoseconds
                let snapshot = try await sampler.sample(includeProcesses: !systemOnly)
                let duration = Double(DispatchTime.now().uptimeNanoseconds - sampleStart) / 1_000_000
                let processCount = snapshot.groups.reduce(0) { $0 + $1.processes.count }
                print(String(format: "sample=%d system_cpu=%.3f%% processors=%d processes=%d unavailable=%d sample_ms=%.3f%@",
                    index + 1, snapshot.systemCPUPercent, snapshot.logicalProcessorCount, processCount,
                    snapshot.unavailableProcessCount, duration, index == 0 ? " baseline" : ""))
                if includeCores {
                    if let percentages = snapshot.coreCPUPercentages {
                        let values = percentages.map { String(format: "%.3f", $0) }.joined(separator: ",")
                        print("  core_cpu_percent=[\(values)] count=\(percentages.count)")
                    } else {
                        print("  core_cpu_percent=unavailable")
                    }
                }
                for group in snapshot.groups.prefix(limit) {
                    print(String(format: "  %.3f%% %@ members=%d resident_mb=%.1f", group.cpuPercent, group.name,
                        group.processes.count, Double(group.residentMemoryBytes) / 1_048_576))
                    for process in group.processes.prefix(5) {
                        let cpu = process.cpuReadingAvailable ? String(format: "%.3f%%", process.cpuPercent) : "unavailable"
                        print("    pid=\(process.pid) cpu=\(cpu) name=\(process.name) executable=\(process.executablePath)")
                    }
                }
            }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            let cpu = ownCPUSeconds() - startCPU
            print(String(format: "probe_elapsed_s=%.3f probe_cpu_s=%.6f probe_machine_cpu=%.4f%% resident_mb=%.2f",
                elapsed, cpu, cpu / max(elapsed, 0.000001) / Double(ProcessInfo.processInfo.activeProcessorCount) * 100,
                ownResidentMegabytes()))
        } catch {
            print("ProcessProbe: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func integerOption(_ name: String, arguments: [String], default fallback: Int) throws -> Int {
        guard let index = arguments.firstIndex(of: name) else { return fallback }
        guard arguments.indices.contains(index + 1), let value = Int(arguments[index + 1]), value > 0 else {
            throw ProbeError.invalidArgument(name)
        }
        return value
    }

    private static func intervalOption(_ arguments: [String]) throws -> Double {
        guard let index = arguments.firstIndex(of: "--interval") else { return 1 }
        guard arguments.indices.contains(index + 1), let value = Double(arguments[index + 1]),
              value.isFinite, value > 0 else { throw ProbeError.invalidArgument("--interval") }
        return value
    }

    private static func ownCPUSeconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    private static func ownResidentMegabytes() -> Double {
        var task = proc_taskinfo()
        guard proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) > 0 else { return 0 }
        return Double(task.pti_resident_size) / 1_048_576
    }

    private static func verifyTermination() async throws {
        let sampler = ProcessSampler()
        let terminator = ProcessTerminator()
        for mode in [TerminationMode.quit, .forceQuit] {
            let fixture = Process()
            fixture.executableURL = URL(fileURLWithPath: "/bin/sleep")
            fixture.arguments = ["60"]
            try fixture.run()
            defer {
                if fixture.isRunning { fixture.terminate() }
                fixture.waitUntilExit()
            }
            let snapshot = try await sampler.sample(includeProcesses: true)
            guard let process = snapshot.groups.flatMap(\.processes).first(where: { $0.pid == fixture.processIdentifier }) else {
                throw ProbeError.fixtureUnavailable
            }
            let stale = ProcessSample(identity: ProcessIdentity(pid: process.pid, uid: process.uid,
                startTimeMicroseconds: process.identity.startTimeMicroseconds + 1), parentPID: process.parentPID,
                name: process.name, executablePath: process.executablePath, cpuPercent: 0,
                residentMemoryBytes: 0, terminationRestriction: nil)
            do {
                try await terminator.terminate(stale, mode: mode)
                throw ProbeError.staleIdentityAccepted
            } catch ProcessCoreError.identityChanged {
                guard fixture.isRunning else { throw ProbeError.staleIdentityAccepted }
            }
            try await terminator.terminate(process, mode: mode)
            fixture.waitUntilExit()
            guard fixture.terminationReason == .uncaughtSignal,
                  fixture.terminationStatus == (mode == .quit ? SIGTERM : SIGKILL) else {
                throw ProbeError.fixtureUnexpectedExit
            }
            print("verified disposable pid=\(process.pid) mode=\(mode) stale_identity_rejected=true signal=\(fixture.terminationStatus)")
        }
    }

    private static func verifyCPU() async throws {
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
        fixture.standardOutput = FileHandle.nullDevice
        fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer {
            if fixture.isRunning { fixture.terminate() }
            fixture.waitUntilExit()
        }
        let sampler = ProcessSampler()
        _ = try await sampler.sample(includeProcesses: true)
        try await Task.sleep(for: .seconds(1.5))
        let snapshot = try await sampler.sample(includeProcesses: true)
        guard let process = snapshot.groups.flatMap(\.processes).first(where: { $0.pid == fixture.processIdentifier }) else {
            throw ProbeError.fixtureUnavailable
        }
        let oneCorePercent = 100 / Double(snapshot.logicalProcessorCount)
        guard process.cpuReadingAvailable, process.cpuPercent >= oneCorePercent * 0.5,
              process.cpuPercent <= oneCorePercent * 1.2 else { throw ProbeError.cpuNormalizationFailed }
        let group = snapshot.groups.first { $0.processes.contains { $0.pid == process.pid } }
        print(String(format: "verified disposable pid=%d observed_cpu=%.3f%% one_core_capacity=%.3f%% processors=%d system_cpu=%.3f%% group=%@",
            process.pid, process.cpuPercent, oneCorePercent, snapshot.logicalProcessorCount,
            snapshot.systemCPUPercent, group?.name ?? "unavailable"))
    }
}

private enum ProbeError: LocalizedError {
    case invalidArgument(String)
    case fixtureUnavailable
    case staleIdentityAccepted
    case fixtureUnexpectedExit
    case cpuNormalizationFailed

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let argument): return "Invalid value for \(argument)."
        case .fixtureUnavailable: return "Disposable fixture was not found in the sample."
        case .staleIdentityAccepted: return "Stale identity was accepted."
        case .fixtureUnexpectedExit: return "Disposable fixture did not receive the requested signal."
        case .cpuNormalizationFailed: return "Disposable CPU fixture did not produce a normalized CPU reading."
        }
    }
}
