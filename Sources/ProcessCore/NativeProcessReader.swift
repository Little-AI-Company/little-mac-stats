import Darwin
import Foundation

struct NativeProcess: Sendable {
    let identity: ProcessIdentity
    let parentPID: Int32
    let realUID: UInt32
    let name: String
    let executablePath: String
    let cpuTicks: UInt64?
    let residentMemoryBytes: UInt64
}

enum NativeProcessReader {
    static func processIDs() throws -> [Int32] {
        let required = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard required > 0 else { throw ProcessCoreError.samplingFailed("process list unavailable") }
        var identifiers = [Int32](repeating: 0, count: Int(required) / MemoryLayout<Int32>.size + 256)
        let bytes = identifiers.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count))
        }
        guard bytes > 0 else { throw ProcessCoreError.samplingFailed("process list unavailable") }
        return Array(identifiers.prefix(Int(bytes) / MemoryLayout<Int32>.size)).filter { $0 > 0 }
    }

    static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size else { return nil }
        return info
    }

    static func identity(_ info: proc_bsdinfo) -> ProcessIdentity {
        ProcessIdentity(pid: Int32(info.pbi_pid), uid: info.pbi_uid,
                        startTimeMicroseconds: info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec)
    }

    static func executablePath(_ pid: Int32) -> String {
        let procPIDPathInfoMaxSize = 4 * Int(MAXPATHLEN)
        var path = [CChar](repeating: 0, count: procPIDPathInfoMaxSize)
        let count = path.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
        guard count > 0 else { return "" }
        return path.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    static func read(_ pid: Int32) -> NativeProcess? {
        guard var info = bsdInfo(pid) else { return nil }
        let firstIdentity = identity(info)
        let path = executablePath(pid)
        var task = proc_taskinfo()
        let taskSize = MemoryLayout<proc_taskinfo>.size
        let hasTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(taskSize)) == taskSize
        guard let checked = bsdInfo(pid), identity(checked) == firstIdentity else { return nil }
        let name = withUnsafeBytes(of: &info.pbi_name) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let fallback = withUnsafeBytes(of: &info.pbi_comm) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return NativeProcess(identity: firstIdentity, parentPID: Int32(info.pbi_ppid), realUID: info.pbi_ruid,
                             name: name.isEmpty ? fallback : name, executablePath: path,
                             cpuTicks: hasTask ? task.pti_total_user + task.pti_total_system : nil,
                             residentMemoryBytes: hasTask ? task.pti_resident_size : 0)
    }

    static func hostTicks() throws -> [UInt32] {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw ProcessCoreError.samplingFailed("host statistics unavailable") }
        return [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
    }

    static func coreTicks() -> [[UInt32]]? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var processorCount: natural_t = 0
        var informationCount: mach_msg_type_number_t = 0
        var information: processor_info_array_t?
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount,
                                         &information, &informationCount)
        defer {
            if let information {
                vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: information)),
                              vm_size_t(informationCount) * vm_size_t(MemoryLayout<integer_t>.stride))
            }
        }
        let statesPerCore = Int(CPU_STATE_MAX)
        guard result == KERN_SUCCESS, let information, processorCount > 0,
              Int(informationCount) == Int(processorCount) * statesPerCore else { return nil }
        return (0..<Int(processorCount)).map { processor in
            let offset = processor * statesPerCore
            return (0..<statesPerCore).map { UInt32(bitPattern: information[offset + $0]) }
        }
    }

    static func ancestorIDs(of pid: Int32) -> Set<Int32> {
        var result: Set<Int32> = []
        var current = pid
        while current > 1, let info = bsdInfo(current) {
            let parent = Int32(info.pbi_ppid)
            guard parent > 0, !result.contains(parent) else { break }
            result.insert(parent)
            current = parent
        }
        return result
    }
}
