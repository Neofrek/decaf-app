import AppKit
import Darwin
import Foundation

@MainActor
final class CaffeinateManager: ObservableObject {
    struct RunningCommand: Identifiable, Equatable {
        let id: UUID
        let pid: Int32?
        let attachedPID: Int32?
        let command: String
    }

    @Published private(set) var runningCommands: [RunningCommand] = []
    @Published var lastError: String?
    @Published var transitionLog: [String] = []

    private let spawnedPIDKey = "DecafSpawnedCaffeinatePIDs"
    private var processes: [UUID: Process] = [:]
    private var attachedByPID: [Int32: UUID] = [:]
    private var expectedTerminations: Set<UUID> = []
    private var terminationObserver: NSObjectProtocol?
    var attachedExitHandler: ((Int32) -> Void)?
    var unexpectedExitHandler: (() -> Void)?

    init() {
        cleanupRegisteredPIDs(reason: "Launch cleanup")
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopAll(reason: "Application terminating")
            }
        }
    }

    func runSingle(profile: CaffeinateProfile, mode: DecafMode) {
        stopAll(reason: "Switching to \(mode.title)")
        launch(profile: profile, mode: mode, attachedPID: nil)
    }

    func runAttached(profile: CaffeinateProfile, pids: [Int32]) {
        stopAll(reason: "Switching to Attached Processes")
        for pid in pids {
            launch(profile: profile, mode: .attached, attachedPID: pid)
        }
    }

    func stopAll(reason: String) {
        cleanupRegisteredPIDs(reason: "\(reason) registered PID cleanup")
        guard !processes.isEmpty else {
            runningCommands.removeAll()
            attachedByPID.removeAll()
            log(reason)
            return
        }

        log(reason)
        expectedTerminations.formUnion(processes.keys)
        for process in processes.values {
            terminate(process)
        }
        processes.removeAll()
        attachedByPID.removeAll()
        runningCommands.removeAll()
        clearRegisteredPIDs()
    }

    func detach(pid: Int32) {
        guard let id = attachedByPID[pid], let process = processes[id] else { return }
        expectedTerminations.insert(id)
        terminate(process)
        processes[id] = nil
        attachedByPID[pid] = nil
        runningCommands.removeAll { $0.id == id || $0.attachedPID == pid }
        unregister(process.processIdentifier)
        log("Detached PID \(pid)")
    }

    private func launch(profile: CaffeinateProfile, mode: DecafMode, attachedPID: Int32?) {
        let args = profile.arguments(attachedPID: attachedPID)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = args
        process.standardOutput = nil
        process.standardError = nil
        let id = UUID()
        let command = (["caffeinate"] + args).joined(separator: " ")

        process.terminationHandler = { [weak self] terminated in
            Task { @MainActor in
                guard let self else { return }
                let wasExpected = self.expectedTerminations.remove(id) != nil
                self.processes[id] = nil
                self.unregister(terminated.processIdentifier)
                self.runningCommands.removeAll { $0.id == id }
                if let attachedPID {
                    self.attachedByPID[attachedPID] = nil
                    self.attachedExitHandler?(attachedPID)
                } else if !wasExpected, terminated.terminationStatus != 0 {
                    self.lastError = "caffeinate exited unexpectedly for \(mode.title)."
                    self.unexpectedExitHandler?()
                }
                self.log("caffeinate exited: \(command)")
            }
        }

        do {
            try process.run()
            processes[id] = process
            register(process.processIdentifier)
            if let attachedPID { attachedByPID[attachedPID] = id }
            runningCommands.append(RunningCommand(id: id, pid: process.processIdentifier, attachedPID: attachedPID, command: command))
            log("Started \(command)")
        } catch {
            lastError = "Unable to launch /usr/bin/caffeinate: \(error.localizedDescription)"
            log("Launch failed: \(command)")
        }
    }

    private func terminate(_ process: Process) {
        let pid = process.processIdentifier
        if process.isRunning {
            process.terminate()
        }
        waitForExit(process, timeout: 1.5)
        if process.isRunning {
            kill(pid, SIGTERM)
        }
        waitForExit(process, timeout: 0.5)
        if process.isRunning {
            kill(pid, SIGKILL)
        }
        unregister(pid)
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    private func cleanupRegisteredPIDs(reason: String) {
        let pids = registeredPIDs()
        guard !pids.isEmpty else { return }
        log(reason)
        for pid in pids where isCaffeinateProcess(pid) {
            kill(pid, SIGTERM)
        }
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, pids.contains(where: isCaffeinateProcess) {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        for pid in pids where isCaffeinateProcess(pid) {
            kill(pid, SIGKILL)
        }
        clearRegisteredPIDs()
    }

    private func register(_ pid: Int32) {
        var pids = Set(registeredPIDs())
        pids.insert(pid)
        UserDefaults.standard.set(Array(pids), forKey: spawnedPIDKey)
    }

    private func unregister(_ pid: Int32) {
        var pids = Set(registeredPIDs())
        pids.remove(pid)
        UserDefaults.standard.set(Array(pids), forKey: spawnedPIDKey)
    }

    private func registeredPIDs() -> [Int32] {
        UserDefaults.standard.array(forKey: spawnedPIDKey)?.compactMap { value in
            if let pid = value as? Int32 { return pid }
            if let pid = value as? Int { return Int32(pid) }
            return nil
        } ?? []
    }

    private func clearRegisteredPIDs() {
        UserDefaults.standard.removeObject(forKey: spawnedPIDKey)
    }

    private func isCaffeinateProcess(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        var buffer = [CChar](repeating: 0, count: 4096)
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return false }
        let count = buffer.firstIndex(of: 0) ?? buffer.count
        let path = String(decoding: buffer.prefix(count).map { byte in UInt8(bitPattern: byte) }, as: UTF8.self)
        return path == "/usr/bin/caffeinate"
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        transitionLog.insert("[\(formatter.string(from: Date()))] \(message)", at: 0)
        transitionLog = Array(transitionLog.prefix(60))
        NSLog("Decaf: \(message)")
    }
}
