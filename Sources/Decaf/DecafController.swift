import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
final class DecafController: ObservableObject {
    @Published var settings: DecafSettings {
        didSet {
            store.save(settings)
            reevaluate(reason: "Settings changed", automatic: true)
        }
    }
    @Published private(set) var currentMode: DecafMode = .off
    @Published private(set) var selectedProcesses: [ProcessInfoItem] = []
    @Published var manualOverride: ManualOverride = .none

    let caffeinate = CaffeinateManager()
    let focus = FocusIntegration()

    private let store = PreferencesStore()
    private let notificationManager = NotificationManager.shared
    private let windowManager = WindowManager()
    private var timer: Timer?
    private var lastScheduledMode: DecafMode?
    private var lastRunSignature: String?
    private var focusChangeCancellable: AnyCancellable?

    init() {
        settings = store.load()
        caffeinate.attachedExitHandler = { [weak self] pid in
            Task { @MainActor in
                self?.selectedProcesses.removeAll { $0.pid == pid }
                if self?.selectedProcesses.isEmpty == true {
                    self?.manualOverride = .none
                    self?.reevaluate(reason: "Attached process exited", automatic: true)
                }
            }
        }
        caffeinate.unexpectedExitHandler = { [weak self] in
            Task { @MainActor in
                self?.reevaluate(reason: "Unexpected caffeinate exit", automatic: true)
            }
        }
        notificationManager.requestAuthorization()
        focusChangeCancellable = focus.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        focus.refresh()
        startTimer()
        reevaluate(reason: "Launch", automatic: true, notify: false)
    }

    func showPreferences() {
        windowManager.showPreferences(controller: self)
    }

    func setFocusIntegrationEnabled(_ enabled: Bool) {
        settings.useSleepFocusForNightMode = enabled
        if enabled {
            if focus.permissionStatus == .notDetermined {
                focus.requestPermission { [weak self] in
                    self?.reevaluate(reason: "Focus integration enabled", automatic: true)
                }
            } else {
                focus.refresh()
                reevaluate(reason: "Focus integration enabled", automatic: true)
            }
        } else {
            focus.refresh()
            reevaluate(reason: "Focus integration disabled", automatic: true)
        }
    }

    func showAttachProcesses() {
        windowManager.showAttach(controller: self)
    }

    func quit() {
        caffeinate.stopAll(reason: "Quit")
        NSApplication.shared.terminate(nil)
    }

    func forceWork() {
        manualOverride = .work(until: settings.schedule.nextBoundary())
        selectedProcesses.removeAll()
        apply(mode: .work, reason: "Manual Work Mode", automatic: false)
    }

    func forceNight() {
        manualOverride = .night(until: settings.schedule.nextBoundary())
        selectedProcesses.removeAll()
        apply(mode: .night, reason: "Manual Night Mode", automatic: false)
    }

    func turnOff() {
        manualOverride = .off(until: settings.schedule.nextBoundary())
        selectedProcesses.removeAll()
        apply(mode: .off, reason: "Manual Off", automatic: false)
    }

    func attach(to processes: [ProcessInfoItem]) {
        guard !processes.isEmpty else { return }
        selectedProcesses = Array(processes.prefix(20))
        manualOverride = .none
        apply(mode: .attached, reason: "Attached \(selectedProcesses.count) process(es)", automatic: false)
    }

    func detachAll() {
        selectedProcesses.removeAll()
        caffeinate.stopAll(reason: "Detach all processes")
        reevaluate(reason: "Detached all processes", automatic: true)
    }

    func detach(pid: Int32) {
        selectedProcesses.removeAll { $0.pid == pid }
        caffeinate.detach(pid: pid)
        if selectedProcesses.isEmpty {
            reevaluate(reason: "Detached final process", automatic: true)
        }
    }

    func reevaluate(reason: String, automatic: Bool = true, notify: Bool = true) {
        focus.refresh()
        clearExpiredManualOverrideIfNeeded()

        if case .off = manualOverride {
            apply(mode: .off, reason: reason, automatic: false)
            return
        }
        if !selectedProcesses.isEmpty {
            apply(mode: .attached, reason: reason, automatic: false)
            return
        }
        switch manualOverride {
        case .work:
            apply(mode: .work, reason: reason, automatic: false)
            return
        case .night:
            apply(mode: .night, reason: reason, automatic: false)
            return
        default:
            break
        }
        if settings.useSleepFocusForNightMode,
           focus.permissionStatus == .available,
           focus.isFocused == true {
            apply(mode: .focusNight, reason: "Focus status is active", automatic: true, notify: notify)
            return
        }
        guard settings.schedule.schedulerEnabled else {
            apply(mode: .off, reason: "Scheduler disabled", automatic: automatic, notify: false)
            return
        }
        let scheduled = settings.schedule.scheduledMode()
        if lastScheduledMode != nil, lastScheduledMode != scheduled {
            manualOverride = .none
        }
        lastScheduledMode = scheduled
        apply(mode: scheduled, reason: "Schedule matched \(scheduled.shortTitle)", automatic: automatic, notify: notify)
    }

    func profileBinding(for kind: ProfileKind) -> Binding<CaffeinateProfile> {
        Binding(
            get: {
                switch kind {
                case .work: self.settings.workProfile
                case .night: self.settings.nightProfile
                case .attached: self.settings.attachedProfile
                }
            },
            set: { profile in
                switch kind {
                case .work: self.settings.workProfile = profile
                case .night: self.settings.nightProfile = profile
                case .attached: self.settings.attachedProfile = profile
                }
            }
        )
    }

    func customModeBinding(for id: UUID) -> Binding<CustomCaffeinateMode>? {
        guard let index = settings.customModes.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.settings.customModes[index] },
            set: { self.settings.customModes[index] = $0 }
        )
    }

    func customProfileBinding(for id: UUID) -> Binding<CaffeinateProfile>? {
        guard let index = settings.customModes.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.settings.customModes[index].profile },
            set: { self.settings.customModes[index].profile = $0 }
        )
    }

    
    func addCustomMode() -> UUID {
        let mode = CustomCaffeinateMode(name: "Custom Mode \(settings.customModes.count + 1)")
        settings.customModes.append(mode)
        return mode.id
    }

    func deleteCustomMode(id: UUID) {
        settings.customModes.removeAll { $0.id == id }
    }

    func binding(for rule: ScheduleRule) -> Binding<ScheduleRule>? {
        guard let index = settings.schedule.rules.firstIndex(where: { $0.id == rule.id }) else { return nil }
        return Binding(
            get: { self.settings.schedule.rules[index] },
            set: { self.settings.schedule.rules[index] = $0 }
        )
    }

    func addScheduleRule(mode: ScheduleMode) {
        let defaults: (Int, Int)
        switch mode {
        case .work: defaults = (8 * 60, 17 * 60)
        case .night: defaults = (22 * 60, 8 * 60)
        case .off: defaults = (17 * 60, 22 * 60)
        }
        settings.schedule.rules.append(
            ScheduleRule(mode: mode, days: Set(Weekday.allCases), startMinutes: defaults.0, endMinutes: defaults.1)
        )
    }

    func deleteScheduleRule(_ rule: ScheduleRule) {
        settings.schedule.rules.removeAll { $0.id == rule.id }
    }

    private func apply(mode: DecafMode, reason: String, automatic: Bool, notify: Bool = true) {
        let previousMode = currentMode
        let signature = runSignature(for: mode)
        if currentMode == mode, lastRunSignature == signature, (!caffeinate.runningCommands.isEmpty || mode == .off) {
            return
        }
        currentMode = mode
        lastRunSignature = signature
        withAnimation(.snappy) {}
        switch mode {
        case .off:
            caffeinate.stopAll(reason: reason)
        case .work:
            caffeinate.runSingle(profile: settings.workProfile, mode: .work)
        case .night, .focusNight:
            caffeinate.runSingle(profile: settings.nightProfile, mode: mode)
        case .attached:
            caffeinate.runAttached(profile: settings.attachedProfile, pids: selectedProcesses.map(\.pid))
        }
        if automatic, notify, previousMode != mode {
            notificationManager.notifyModeChange(mode: mode, reason: reason)
        }
    }

    private func runSignature(for mode: DecafMode) -> String {
        switch mode {
        case .off:
            "off"
        case .work:
            "work:\(settings.workProfile.commandPreview())"
        case .night, .focusNight:
            "\(mode.rawValue):\(settings.nightProfile.commandPreview())"
        case .attached:
            "attached:\(settings.attachedProfile.commandPreview(attachedPID: 0)):\(selectedProcesses.map(\.pid).sorted())"
        }
    }

    private func clearExpiredManualOverrideIfNeeded() {
        guard let expiration = manualOverride.expiration, expiration <= Date() else { return }
        manualOverride = .none
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reevaluate(reason: "Schedule check", automatic: true)
            }
        }
    }
}
