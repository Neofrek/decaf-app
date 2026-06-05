import Foundation

enum ProcessCatalog {
    static func load() async -> [ProcessInfoItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: loadSynchronously())
            }
        }
    }

    private static func loadSynchronously() -> [ProcessInfoItem] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm=,command="]
        process.standardOutput = output
        process.standardError = nil

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else { return [] }
            let currentPID = Int32(ProcessInfo.processInfo.processIdentifier)
            return text.split(separator: "\n").compactMap { line in
                parse(String(line), currentPID: currentPID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            NSLog("Decaf failed to list processes: \(error.localizedDescription)")
            return []
        }
    }

    private static func parse(_ line: String, currentPID: Int32) -> ProcessInfoItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let firstSpace = trimmed.firstIndex(where: \.isWhitespace),
              let pid = Int32(trimmed[..<firstSpace]),
              pid != currentPID else { return nil }
        let rest = trimmed[firstSpace...].trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let comm = parts.first else { return nil }
        let command = parts.count > 1 ? String(parts[1]) : String(comm)
        let name = URL(fileURLWithPath: String(comm)).lastPathComponent
        return ProcessInfoItem(pid: pid, name: name.isEmpty ? String(comm) : name, command: command)
    }
}
