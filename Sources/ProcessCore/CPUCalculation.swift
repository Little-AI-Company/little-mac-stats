import Foundation

enum CPUCalculation {
    static func processPercent(previous: UInt64, current: UInt64, elapsedNanoseconds: UInt64,
                               processorCount: Int, nanosecondsPerTick: Double = 1) -> Double {
        guard current >= previous, elapsedNanoseconds > 0, processorCount > 0,
              nanosecondsPerTick.isFinite, nanosecondsPerTick > 0 else { return 0 }
        // Convert the delta as a Double; multiplying absolute UInt64 counters can overflow.
        let percent = Double(current - previous) * nanosecondsPerTick
            / Double(elapsedNanoseconds) / Double(processorCount) * 100
        return min(100, max(0, percent))
    }

    static func systemPercent(previous: [UInt32], current: [UInt32]) -> Double {
        guard previous.count == current.count, current.count == 4 else { return 0 }
        // Host tick counters are 32-bit and wrap during long uptime.
        let deltas = zip(previous, current).map { UInt64($1 &- $0) }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return 0 }
        let idle = deltas[2]
        return Double(total - idle) / Double(total) * 100
    }
}
