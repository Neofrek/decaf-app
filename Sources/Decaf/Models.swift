import Foundation
import SwiftUI

enum DecafMode: String, Codable, CaseIterable, Identifiable {
    case off
    case work
    case night
    case attached
    case focusNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .work: "Work Mode"
        case .night: "Night Mode"
        case .attached: "Attached Processes"
        case .focusNight: "Focus Night Mode"
        }
    }

    var shortTitle: String {
        switch self {
        case .off: "Off"
        case .work: "Work"
        case .night, .focusNight: "Night"
        case .attached: "Attached"
        }
    }

    var symbolName: String {
        switch self {
        case .off: "pause.circle"
        case .work: "display"
        case .night: "moon"
        case .attached: "link.circle"
        case .focusNight: "moon.stars"
        }
    }
}

enum ProfileKind: String, CaseIterable, Identifiable {
    case work
    case night
    case attached

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: "Work Mode"
        case .night: "Night Mode"
        case .attached: "Attached Processes"
        }
    }
}

struct CustomCaffeinateMode: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var profile: CaffeinateProfile

    init(id: UUID = UUID(), name: String = "Custom Mode", profile: CaffeinateProfile = .nightDefault) {
        self.id = id
        self.name = name
        self.profile = profile
    }
}

enum ManualOverride: Equatable {
    case none
    case off(until: Date?)
    case work(until: Date?)
    case night(until: Date?)

    var isActive: Bool {
        switch self {
        case .none: false
        default: true
        }
    }

    var expiration: Date? {
        switch self {
        case .none: nil
        case .off(let until), .work(let until), .night(let until): until
        }
    }
}

struct CaffeinateProfile: Codable, Equatable {
    var preventDisplaySleep: Bool
    var preventIdleSleep: Bool
    var preventDiskSleep: Bool
    var preventSystemSleep: Bool
    var timeoutSeconds: Int?
    var utilityMode: Bool
    var customArgumentsEnabled: Bool
    var customArguments: String

    static let workDefault = CaffeinateProfile(
        preventDisplaySleep: true,
        preventIdleSleep: false,
        preventDiskSleep: false,
        preventSystemSleep: false,
        timeoutSeconds: nil,
        utilityMode: false,
        customArgumentsEnabled: false,
        customArguments: ""
    )

    static let nightDefault = CaffeinateProfile(
        preventDisplaySleep: false,
        preventIdleSleep: true,
        preventDiskSleep: false,
        preventSystemSleep: true,
        timeoutSeconds: nil,
        utilityMode: false,
        customArgumentsEnabled: false,
        customArguments: ""
    )

    static let attachedDefault = CaffeinateProfile(
        preventDisplaySleep: false,
        preventIdleSleep: true,
        preventDiskSleep: false,
        preventSystemSleep: false,
        timeoutSeconds: nil,
        utilityMode: false,
        customArgumentsEnabled: false,
        customArguments: ""
    )

    func arguments(attachedPID: Int32? = nil) -> [String] {
        var args: [String] = []
        if preventDisplaySleep { args.append("-d") }
        if preventIdleSleep { args.append("-i") }
        if preventDiskSleep { args.append("-m") }
        if preventSystemSleep { args.append("-s") }
        if utilityMode { args.append("-u") }
        if let timeoutSeconds, timeoutSeconds > 0 {
            args.append(contentsOf: ["-t", String(timeoutSeconds)])
        }
        if customArgumentsEnabled {
            args.append(contentsOf: Self.splitCustomArguments(customArguments))
        }
        if let attachedPID {
            args.append(contentsOf: ["-w", String(attachedPID)])
        }
        return args
    }

    func commandPreview(attachedPID: Int32? = nil) -> String {
        (["caffeinate"] + arguments(attachedPID: attachedPID)).joined(separator: " ")
    }

    func validationWarnings(attachedPID: Int32? = nil) -> [String] {
        var warnings: [String] = []
        let custom = Self.splitCustomArguments(customArguments)
        let allowedFlags: Set<String> = ["-d", "-i", "-m", "-s", "-t", "-u", "-w"]

        if preventSystemSleep {
            warnings.append("Prevent system sleep may require AC power on some Macs/macOS versions.")
        }
        if utilityMode, timeoutSeconds == nil {
            warnings.append("Utility mode is best for short wake/display behavior, not overnight jobs.")
        }
        if customArgumentsEnabled {
            for arg in custom where arg.hasPrefix("-") && !allowedFlags.contains(arg) {
                warnings.append("Custom argument \(arg) may be unsupported by /usr/bin/caffeinate.")
            }
            let generated = Set(arguments(attachedPID: nil).filter { $0.hasPrefix("-") })
            let raw = Set(custom.filter { $0.hasPrefix("-") })
            let overlap = generated.intersection(raw).sorted()
            if !overlap.isEmpty {
                warnings.append("Custom arguments repeat generated flags: \(overlap.joined(separator: ", ")).")
            }
            if custom.contains("-w"), attachedPID != nil {
                warnings.append("Attached process mode adds -w automatically; remove custom -w to avoid conflicts.")
            }
            if custom.contains("-t"), timeoutSeconds != nil {
                warnings.append("Timeout is already configured; remove custom -t to avoid conflicts.")
            }
        }
        return warnings
    }

    static func splitCustomArguments(_ raw: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false

        for character in raw {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                continue
            }
            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                } else if quote == nil {
                    quote = character
                } else {
                    current.append(character)
                }
                continue
            }
            if character.isWhitespace, quote == nil {
                if !current.isEmpty {
                    result.append(current)
                    current.removeAll()
                }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case work
    case night
    case off

    var id: String { rawValue }

    var decafMode: DecafMode {
        switch self {
        case .work: .work
        case .night: .night
        case .off: .off
        }
    }

    var title: String {
        switch self {
        case .work: "Work"
        case .night: "Night"
        case .off: "Off"
        }
    }

    var symbolName: String { decafMode.symbolName }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }
}

struct ScheduleRule: Codable, Identifiable, Equatable {
    var id: UUID
    var mode: ScheduleMode
    var enabled: Bool
    var days: Set<Weekday>
    var startMinutes: Int
    var endMinutes: Int

    init(id: UUID = UUID(), mode: ScheduleMode, enabled: Bool = true, days: Set<Weekday>, startMinutes: Int, endMinutes: Int) {
        self.id = id
        self.mode = mode
        self.enabled = enabled
        self.days = days
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    var isOvernight: Bool { endMinutes <= startMinutes }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, !days.isEmpty else { return false }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekdayValue = components.weekday,
              let weekday = Weekday(rawValue: weekdayValue) else { return false }
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes < endMinutes {
            return days.contains(weekday) && minute >= startMinutes && minute < endMinutes
        }

        if days.contains(weekday), minute >= startMinutes {
            return true
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        let previousWeekdayValue = calendar.component(.weekday, from: yesterday)
        guard let previousWeekday = Weekday(rawValue: previousWeekdayValue) else { return false }
        return days.contains(previousWeekday) && minute < endMinutes
    }

    func boundaryDates(after date: Date, calendar: Calendar = .current) -> [Date] {
        guard enabled else { return [] }
        let startOfToday = calendar.startOfDay(for: date)
        var dates: [Date] = []
        for offset in -1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let start = calendar.date(byAdding: .minute, value: startMinutes, to: day),
                  let endBase = calendar.date(byAdding: .minute, value: endMinutes, to: day) else { continue }
            let weekdayValue = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayValue), days.contains(weekday) else { continue }
            dates.append(start)
            dates.append(isOvernight ? calendar.date(byAdding: .day, value: 1, to: endBase) ?? endBase : endBase)
        }
        return dates.filter { $0 > date }
    }

    var timeSummary: String {
        "\(Self.timeText(startMinutes)) - \(Self.timeText(endMinutes))"
    }

    var daySummary: String {
        if days.count == Weekday.allCases.count { return "Every day" }
        return Weekday.allCases.filter { days.contains($0) }.map(\.shortTitle).joined(separator: ", ")
    }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

struct ScheduleSettings: Codable, Equatable {
    var schedulerEnabled: Bool
    var workStartMinutes: Int
    var nightStartMinutes: Int
    var startAtLogin: Bool
    var rules: [ScheduleRule]

    init(
        schedulerEnabled: Bool = true,
        workStartMinutes: Int = 8 * 60,
        nightStartMinutes: Int = 22 * 60,
        startAtLogin: Bool = false,
        rules: [ScheduleRule] = ScheduleSettings.defaultRules
    ) {
        self.schedulerEnabled = schedulerEnabled
        self.workStartMinutes = workStartMinutes
        self.nightStartMinutes = nightStartMinutes
        self.startAtLogin = startAtLogin
        self.rules = rules
    }

    static var defaultRules: [ScheduleRule] {
        let everyDay = Set(Weekday.allCases)
        return [
            ScheduleRule(mode: .work, days: everyDay, startMinutes: 8 * 60, endMinutes: 22 * 60),
            ScheduleRule(mode: .night, days: everyDay, startMinutes: 22 * 60, endMinutes: 8 * 60)
        ]
    }

    enum CodingKeys: String, CodingKey {
        case schedulerEnabled
        case workStartMinutes
        case nightStartMinutes
        case startAtLogin
        case rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schedulerEnabled = try container.decodeIfPresent(Bool.self, forKey: .schedulerEnabled) ?? true
        workStartMinutes = try container.decodeIfPresent(Int.self, forKey: .workStartMinutes) ?? 8 * 60
        nightStartMinutes = try container.decodeIfPresent(Int.self, forKey: .nightStartMinutes) ?? 22 * 60
        startAtLogin = try container.decodeIfPresent(Bool.self, forKey: .startAtLogin) ?? false
        rules = try container.decodeIfPresent([ScheduleRule].self, forKey: .rules) ?? [
            ScheduleRule(mode: .work, days: Set(Weekday.allCases), startMinutes: workStartMinutes, endMinutes: nightStartMinutes),
            ScheduleRule(mode: .night, days: Set(Weekday.allCases), startMinutes: nightStartMinutes, endMinutes: workStartMinutes)
        ]
    }

    func scheduledMode(at date: Date = Date(), calendar: Calendar = .current) -> DecafMode {
        for mode in [ScheduleMode.off, .work, .night] {
            if rules.contains(where: { $0.mode == mode && $0.contains(date, calendar: calendar) }) {
                return mode.decafMode
            }
        }
        return .off
    }

    func nextBoundary(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        rules.flatMap { $0.boundaryDates(after: date, calendar: calendar) }.min()
    }
}

struct ProcessInfoItem: Identifiable, Hashable, Codable {
    let pid: Int32
    let name: String
    let command: String

    var id: Int32 { pid }
}

enum FocusPermissionStatus: String {
    case available = "Available"
    case denied = "Permission denied"
    case notSupported = "Not supported on this macOS version"
    case unable = "Unable to determine"
    case notDetermined = "Not requested"
}
