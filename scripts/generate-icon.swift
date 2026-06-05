import Foundation

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
process.arguments = ["scripts/prepare-app-icons.swift"]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
