import Foundation

struct DecafSettings: Codable, Equatable {
    var advancedModeEnabled: Bool
    var schedule: ScheduleSettings
    var useSleepFocusForNightMode: Bool
    var workProfile: CaffeinateProfile
    var nightProfile: CaffeinateProfile
    var attachedProfile: CaffeinateProfile
    var customModes: [CustomCaffeinateMode]

    init(
        advancedModeEnabled: Bool = false,
        schedule: ScheduleSettings = ScheduleSettings(),
        useSleepFocusForNightMode: Bool = false,
        workProfile: CaffeinateProfile = .workDefault,
        nightProfile: CaffeinateProfile = .nightDefault,
        attachedProfile: CaffeinateProfile = .attachedDefault,
        customModes: [CustomCaffeinateMode] = []
    ) {
        self.advancedModeEnabled = advancedModeEnabled
        self.schedule = schedule
        self.useSleepFocusForNightMode = useSleepFocusForNightMode
        self.workProfile = workProfile
        self.nightProfile = nightProfile
        self.attachedProfile = attachedProfile
        self.customModes = customModes
    }

    enum CodingKeys: String, CodingKey {
        case advancedModeEnabled
        case schedule
        case useSleepFocusForNightMode
        case workProfile
        case nightProfile
        case attachedProfile
        case customModes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        advancedModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .advancedModeEnabled) ?? false
        schedule = try container.decodeIfPresent(ScheduleSettings.self, forKey: .schedule) ?? ScheduleSettings()
        useSleepFocusForNightMode = try container.decodeIfPresent(Bool.self, forKey: .useSleepFocusForNightMode) ?? false
        workProfile = try container.decodeIfPresent(CaffeinateProfile.self, forKey: .workProfile) ?? .workDefault
        nightProfile = try container.decodeIfPresent(CaffeinateProfile.self, forKey: .nightProfile) ?? .nightDefault
        attachedProfile = try container.decodeIfPresent(CaffeinateProfile.self, forKey: .attachedProfile) ?? .attachedDefault
        customModes = try container.decodeIfPresent([CustomCaffeinateMode].self, forKey: .customModes) ?? []
    }
}

final class PreferencesStore {
    private let key = "Decaf.settings.v1"
    private let networkNightMigrationKey = "Decaf.migrations.networkNight.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DecafSettings {
        let settings: DecafSettings
        if let data = defaults.data(forKey: key) {
            do {
                settings = try JSONDecoder().decode(DecafSettings.self, from: data)
            } catch {
                NSLog("Decaf failed to decode settings: \(error.localizedDescription)")
                return DecafSettings()
            }
        } else {
            settings = DecafSettings()
        }
        return migrate(settings)
    }

    func save(_ settings: DecafSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: key)
        } catch {
            NSLog("Decaf failed to save settings: \(error.localizedDescription)")
        }
    }

    private func migrate(_ settings: DecafSettings) -> DecafSettings {
        guard !defaults.bool(forKey: networkNightMigrationKey) else { return settings }
        var migrated = settings
        migrated.nightProfile.preventSystemSleep = true
        defaults.set(true, forKey: networkNightMigrationKey)
        save(migrated)
        return migrated
    }
}
