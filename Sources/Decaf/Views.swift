import SwiftUI

private let decafAnimation = Animation.easeInOut(duration: 0.18)

struct DecafMenuView: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            MenuStatusHeader()

            if !controller.caffeinate.runningCommands.isEmpty {
                CommandGlassPanel(commands: controller.caffeinate.runningCommands.map(\.command))
            }

            if controller.settings.useSleepFocusForNightMode {
                FocusBanner()
            }

            ModeQuickActions()

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { controller.showAttachProcesses() }
            } label: {
                HStack {
                    Label("Attach to Processes", systemImage: "link.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())

            if !controller.selectedProcesses.isEmpty {
                ActiveProcessesMenuPanel()
            }

            if let error = controller.caffeinate.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FooterActions()
        }
        .padding(14)
        .frame(width: 380)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

struct MenuStatusHeader: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: controller.currentMode.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(controller.currentMode.title)
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Auto Schedule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Toggle("", isOn: Binding(
                    get: { controller.settings.schedule.schedulerEnabled },
                    set: { controller.settings.schedule.schedulerEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .tint(.accentColor)
                .help("Enable automatic schedule changes")
                Text(controller.settings.schedule.schedulerEnabled ? "On" : "Paused")
                    .font(.caption2)
                    .foregroundStyle(controller.settings.schedule.schedulerEnabled ? Color.green : Color.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var statusColor: Color {
        switch controller.currentMode {
        case .off: .secondary
        case .work: .blue
        case .night: .indigo
        case .attached: .teal
        case .focusNight: .purple
        }
    }

    private var statusLine: String {
        switch controller.currentMode {
        case .off: "No Decaf session is running."
        case .work: "Keeping the display awake."
        case .night: "Keeping the Mac awake while idle."
        case .attached: "Watching \(controller.selectedProcesses.count) selected process(es)."
        case .focusNight: "Night Mode is active because Shared Focus Status is active."
        }
    }
}

struct ModeQuickActions: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 8) {
            ModeActionButton(title: "Work", subtitle: "Screen awake", symbol: "display", color: .blue, isActive: controller.currentMode == .work, action: controller.forceWork)
            ModeActionButton(title: "Night", subtitle: "Idle awake", symbol: "moon", color: .indigo, isActive: controller.currentMode == .night || controller.currentMode == .focusNight, action: controller.forceNight)
            ModeActionButton(title: "Off", subtitle: "Stop Decaf", symbol: "pause.circle", color: .secondary, isActive: controller.currentMode == .off, action: controller.turnOff)
        }
    }
}

struct ModeActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isActive ? .white : color)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .white.opacity(0.78) : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.thinMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(isActive ? 0.24 : 0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CommandGlassPanel: View {
    let commands: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Running command", systemImage: "terminal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(commands, id: \.self) { command in
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FocusBanner: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Label(controller.focus.message, systemImage: "moon.stars")
            .font(.caption)
            .foregroundStyle(controller.focus.permissionStatus == .available ? Color.secondary : Color.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ActiveProcessesMenuPanel: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Attached", systemImage: "link.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Detach All") { controller.detachAll() }.font(.caption)
            }

            ForEach(controller.selectedProcesses) { process in
                HStack(spacing: 8) {
                    ProcessGlyph(name: process.name)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(process.name).font(.caption.weight(.medium)).lineLimit(1)
                        Text("PID \(process.pid)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { controller.detach(pid: process.pid) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Detach \(process.name)")
                }
            }
        }
        .padding(11)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FooterActions: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { controller.showPreferences() }
            } label: { Label("Preferences", systemImage: "gearshape") }
            Spacer()
            Button(role: .destructive) { controller.quit() } label: { Label("Quit", systemImage: "power") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

enum ModeEditorSelection: Hashable {
    case builtIn(ProfileKind)
    case custom(UUID)
}

struct PreferencesView: View {
    @State private var selectedMode: ModeEditorSelection = .builtIn(.work)

    var body: some View {
        TabView {
            SchedulePreferencesView()
                .tabItem { Label("Sleep Schedule", systemImage: "clock") }
            FocusPreferencesView()
                .tabItem { Label("Focus", systemImage: "moon.stars") }
            ModePreferencesView(selectedMode: $selectedMode)
                .tabItem { Label("Modes", systemImage: "slider.horizontal.3") }
        }
        .padding(20)
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background {
            LinearGradient(colors: [Color.white.opacity(0.12), Color.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }
}

struct SchedulePreferencesView: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreferenceHeader(
                title: "Sleep Schedule",
                subtitle: "Decaf cannot read Apple Sleep Focus schedules directly. Use these rules as Decaf's reliable sleep and work schedule; manual mode choices hold until the next rule boundary.",
                symbol: "clock"
            )

            GlassSection {
                Toggle("Automatic Schedule", isOn: Binding(
                    get: { controller.settings.schedule.schedulerEnabled },
                    set: { controller.settings.schedule.schedulerEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .tint(.accentColor)
                Text("When enabled, Decaf automatically switches modes from the rules below. Night rules continue to use your existing Night Mode settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Toggle("Start at login", isOn: Binding(
                    get: { controller.settings.schedule.startAtLogin },
                    set: { controller.settings.schedule.startAtLogin = $0 }
                ))
                .tint(.accentColor)
            }

            if controller.settings.useSleepFocusForNightMode {
                InfoNote(symbol: "moon.stars", text: "Shared Focus Status is enabled. It is a generic Apple Focus signal, not a direct Sleep Focus reader, and it takes priority over these schedule rules when active.", color: .orange)
                    .padding(.horizontal, 4)
            }

            HStack {
                Text("Sleep Schedule Rules").font(.headline)
                Text("top rule wins").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button { controller.addScheduleRule(mode: .work) } label: { Label("Work rule", systemImage: "display") }
                    Button { controller.addScheduleRule(mode: .night) } label: { Label("Night rule", systemImage: "moon") }
                    Button { controller.addScheduleRule(mode: .off) } label: { Label("Off rule", systemImage: "pause.circle") }
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }

            List {
                ForEach(Array(controller.settings.schedule.rules.enumerated()), id: \.element.id) { index, rule in
                    if let binding = controller.binding(for: rule) {
                        ScheduleRuleEditor(index: index, rule: binding) {
                            controller.deleteScheduleRule(rule)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .onMove { source, destination in
                    controller.settings.schedule.rules.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            InfoNote(symbol: "bell", text: "Automatic mode changes from Decaf schedule rules or Shared Focus Status will send a notification when notification permission is allowed.")
            InfoNote(symbol: "exclamationmark.triangle", text: "Closing the lid may still put your Mac to sleep unless using clamshell mode.")
        }
    }
}

struct ScheduleRuleEditor: View {
    let index: Int
    @Binding var rule: ScheduleRule
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Picker("Mode", selection: $rule.mode) {
                    ForEach(ScheduleMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)

                CompactTimeStepper(minutes: $rule.startMinutes)
                Text("to").font(.caption).foregroundStyle(.secondary)
                CompactTimeStepper(minutes: $rule.endMinutes)

                Spacer(minLength: 6)
                Toggle("", isOn: $rule.enabled).toggleStyle(.switch).tint(.accentColor).help("Enable rule")
                Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Delete rule")
            }

            HStack(spacing: 8) {
                DayPicker(days: $rule.days)
                Spacer()
                if rule.isOvernight {
                    Text("overnight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }
                Text(rule.daySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(rule.enabled ? 1 : 0.55)
    }
}

struct DayPicker: View {
    @Binding var days: Set<Weekday>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases) { day in
                Button {
                    if days.contains(day) { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(String(day.shortTitle.prefix(1)))
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 22)
                        .background(days.contains(day) ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.thinMaterial), in: Capsule())
                        .foregroundStyle(days.contains(day) ? .white : .primary)
                }
                .buttonStyle(.plain)
                .help(day.shortTitle)
            }
        }
    }
}

struct FocusPreferencesView: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreferenceHeader(
                    title: "Shared Focus Status",
                    subtitle: "Use Apple's public shared Focus signal as an optional Night Mode override. This does not identify Sleep Focus or read Apple Sleep schedules.",
                    symbol: "moon.stars"
                )

                GlassSection {
                    Toggle("Use Shared Focus Status for Night Mode", isOn: Binding(
                        get: { controller.settings.useSleepFocusForNightMode },
                        set: { enabled in controller.setFocusIntegrationEnabled(enabled) }
                    ))
                    .tint(.accentColor)
                    Divider()
                    StatusRow("Permission", controller.focus.permissionStatus.rawValue)
                    StatusRow("Shared status", focusStateText)
                    Divider()
                    HStack {
                        Button { controller.focus.requestPermission { controller.reevaluate(reason: "Focus permission changed") } } label: { Label("Request Permission", systemImage: "hand.raised") }
                        Button {
                            controller.focus.refresh()
                            controller.reevaluate(reason: "Focus refresh")
                        } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    }
                    .buttonStyle(.bordered)
                }

                InfoNote(symbol: controller.focus.permissionStatus == .available ? "checkmark.circle.fill" : "exclamationmark.triangle", text: controller.focus.message, color: controller.focus.permissionStatus == .available ? .secondary : .orange)
                InfoNote(text: controller.focus.detail)
                InfoNote(text: "For exact sleep hours, use Decaf's Sleep Schedule rules. Apple does not provide a public macOS API for Decaf to read the Sleep Focus name or Apple Sleep schedule.")
            }
        }
        .onAppear { controller.focus.refresh() }
    }

    private var focusStateText: String {
        guard controller.focus.permissionStatus == .available else { return "Unable to determine" }
        if controller.focus.isFocused == true { return "Active for Decaf" }
        if controller.focus.isFocused == false { return "Inactive for Decaf" }
        return "Unable to determine"
    }
}

struct ModePreferencesView: View {
    @EnvironmentObject private var controller: DecafController
    @Binding var selectedMode: ModeEditorSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreferenceHeader(title: "Modes", subtitle: "Configure what each Decaf mode does without memorizing caffeinate flags.", symbol: "slider.horizontal.3")

            HStack(alignment: .top, spacing: 14) {
                ModeSidebar(selectedMode: $selectedMode)
                    .frame(width: 190)

                VStack(alignment: .leading, spacing: 12) {
                    modeEditor
                    AdvancedModeRow()
                }
            }
        }
        .onChange(of: controller.settings.customModes) { customModes in
            if case .custom(let id) = selectedMode, !customModes.contains(where: { $0.id == id }) {
                selectedMode = .builtIn(.work)
            }
        }
    }

    @ViewBuilder
    private var modeEditor: some View {
        switch selectedMode {
        case .builtIn(let kind):
            if controller.settings.advancedModeEnabled {
                AdvancedProfileEditor(
                    title: kind.title,
                    symbolName: kind.symbolName,
                    isAttached: kind == .attached,
                    profile: controller.profileBinding(for: kind),
                    reset: { resetBuiltIn(kind) }
                )
            } else {
                ProfileBuilderView(title: kind.title, isAttached: kind == .attached, profile: controller.profileBinding(for: kind))
            }
        case .custom(let id):
            if let mode = controller.customModeBinding(for: id), let profile = controller.customProfileBinding(for: id) {
                CustomModeEditor(mode: mode, profile: profile, advanced: controller.settings.advancedModeEnabled) {
                    controller.deleteCustomMode(id: id)
                }
            }
        }
    }

    private func resetBuiltIn(_ kind: ProfileKind) {
        switch kind {
        case .work: controller.settings.workProfile = .workDefault
        case .night: controller.settings.nightProfile = .nightDefault
        case .attached: controller.settings.attachedProfile = .attachedDefault
        }
    }
}

struct ModeSidebar: View {
    @EnvironmentObject private var controller: DecafController
    @Binding var selectedMode: ModeEditorSelection

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(ProfileKind.allCases) { kind in
                    ModeSidebarButton(
                        title: kind.title,
                        symbol: kind.symbolName,
                        isSelected: selectedMode == .builtIn(kind)
                    ) {
                        selectedMode = .builtIn(kind)
                    }
                }

                if !controller.settings.customModes.isEmpty {
                    Divider()
                    ForEach(controller.settings.customModes) { mode in
                        ModeSidebarButton(
                            title: mode.name,
                            symbol: "slider.horizontal.3",
                            isSelected: selectedMode == .custom(mode.id)
                        ) {
                            selectedMode = .custom(mode.id)
                        }
                    }
                }

                Divider()
                Button {
                    let id = controller.addCustomMode()
                    selectedMode = .custom(id)
                } label: {
                    Label("Add Custom Mode", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct ModeSidebarButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AdvancedModeRow: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 10) {
            Text("Advanced Mode")
                .font(.subheadline.weight(.semibold))
            Text("Raw caffeinate arguments")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { controller.settings.advancedModeEnabled },
                set: { controller.settings.advancedModeEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .tint(.accentColor)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CustomModeEditor: View {
    @Binding var mode: CustomCaffeinateMode
    @Binding var profile: CaffeinateProfile
    let advanced: Bool
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSection {
                HStack {
                    TextField("Mode name", text: $mode.name)
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive, action: delete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
                InfoNote(text: "Custom modes are saved here as reusable caffeinate configurations. Core scheduling still uses Work, Night, and Off rules.")
            }

            if advanced {
                AdvancedProfileEditor(title: mode.name, symbolName: "slider.horizontal.3", isAttached: false, profile: $profile) {
                    profile = .nightDefault
                }
            } else {
                ProfileBuilderView(title: mode.name, isAttached: false, profile: $profile)
            }
        }
    }
}

struct ProfileBuilderView: View {
    let title: String
    let isAttached: Bool
    @Binding var profile: CaffeinateProfile
    @State private var timedPresetHours = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PresetButtons(profile: $profile, timedPresetHours: $timedPresetHours)

                GlassSection {
                    OptionToggle(symbol: "display", title: "Prevent display sleep", flag: "-d", explanation: "Keeps the screen awake.", isOn: $profile.preventDisplaySleep)
                    Divider()
                    OptionToggle(symbol: "moon", title: "Prevent idle system sleep", flag: "-i", explanation: "Keeps the Mac awake while idle.", isOn: $profile.preventIdleSleep)
                    Divider()
                    OptionToggle(symbol: "externaldrive", title: "Prevent disk sleep", flag: "-m", explanation: "Keeps disks awake.", isOn: $profile.preventDiskSleep)
                    Divider()
                    OptionToggle(symbol: "bolt.horizontal", title: "Prevent system sleep", flag: "-s", explanation: "Keeps the system awake so network work can continue. May require AC power.", isOn: $profile.preventSystemSleep)
                    Divider()
                    OptionToggle(symbol: "cursorarrow.click", title: "Utility mode", flag: "-u", explanation: "Declares user activity. Best for short wake/display behavior.", isOn: $profile.utilityMode)
                    Divider()
                    TimeoutPicker(profile: $profile)
                    if isAttached {
                        Divider()
                        InfoNote(symbol: "link.circle", text: "Attach to process is added automatically for each selected PID.")
                    }
                }

                CommandPreview(profile: profile, attached: isAttached)
            }
        }
    }
}

struct PresetButtons: View {
    @Binding var profile: CaffeinateProfile
    @Binding var timedPresetHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                PresetButton(title: "Screen Awake", symbol: "display") { profile = .workDefault }
                PresetButton(title: "Network Overnight", symbol: "network") { profile = .nightDefault }
                PresetButton(title: "External Disk", symbol: "externaldrive") {
                    profile = .nightDefault
                    profile.preventDiskSleep = true
                }
                PresetButton(title: "Timed Session", symbol: "timer") {
                    profile = .nightDefault
                    profile.timeoutSeconds = timedPresetHours * 3600
                }
                PresetButton(title: "Process Bound", symbol: "link.circle") { profile = .attachedDefault }
            }
        }
    }
}

struct PresetButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}

struct TimeoutPicker: View {
    @Binding var profile: CaffeinateProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "timer").frame(width: 22).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Timeout", isOn: Binding(
                        get: { profile.timeoutSeconds != nil },
                        set: { enabled in profile.timeoutSeconds = enabled ? 8 * 3600 : nil }
                    ))
                    .tint(.accentColor)
                    Text("Automatically stops after a set duration.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if profile.timeoutSeconds != nil {
                HStack {
                    Stepper("Hours: \(hours)", value: Binding(get: { hours }, set: { update(hours: $0, minutes: minutes) }), in: 0...72)
                    Stepper("Minutes: \(minutes)", value: Binding(get: { minutes }, set: { update(hours: hours, minutes: $0) }), in: 0...59)
                }
                .padding(.leading, 32)
                .transition(.opacity)
            }
        }
        .animation(decafAnimation, value: profile.timeoutSeconds)
    }

    private var hours: Int { (profile.timeoutSeconds ?? 0) / 3600 }
    private var minutes: Int { ((profile.timeoutSeconds ?? 0) % 3600) / 60 }

    private func update(hours: Int, minutes: Int) {
        profile.timeoutSeconds = max(60, hours * 3600 + minutes * 60)
    }
}

struct CommandPreview: View {
    let profile: CaffeinateProfile
    let attached: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Command preview", systemImage: "terminal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(profile.commandPreview(attachedPID: attached ? 12345 : nil).replacingOccurrences(of: "12345", with: "<PID>"))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
            ForEach(profile.validationWarnings(attachedPID: attached ? 12345 : nil), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct AdvancedProfileEditor: View {
    let title: String
    let symbolName: String
    let isAttached: Bool
    @Binding var profile: CaffeinateProfile
    let reset: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassSection {
                    Label(title, systemImage: symbolName).font(.headline)
                    Toggle("Use custom raw arguments", isOn: $profile.customArgumentsEnabled)
                        .tint(.accentColor)
                    TextField("Example: -i -m", text: $profile.customArguments)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!profile.customArgumentsEnabled)
                    InfoNote(symbol: "exclamationmark.triangle", text: "Raw arguments are appended to the generated command. Decaf will warn about duplicates or unsupported flags.", color: .orange)
                }
                CommandPreview(profile: profile, attached: isAttached)
                Button(role: .destructive, action: reset) {
                    Label("Reset This Mode", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}
struct AttachProcessesView: View {
    @EnvironmentObject private var controller: DecafController
    @Environment(\.dismiss) private var dismiss
    @State private var allProcesses: [ProcessInfoItem] = []
    @State private var selected: Set<ProcessInfoItem> = []
    @State private var query = ""
    @State private var isLoading = false

    private var filtered: [ProcessInfoItem] {
        let source = query.isEmpty ? allProcesses : allProcesses.filter {
            $0.name.localizedCaseInsensitiveContains(query) || String($0.pid).contains(query) || $0.command.localizedCaseInsensitiveContains(query)
        }
        return Array(source.prefix(200))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreferenceHeader(title: "Attach to Processes", subtitle: "Keep the Mac awake while selected processes are running.", symbol: "link.circle")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by name, PID, or command", text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                }
                Button { refresh() } label: { Label(isLoading ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise") }
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            FlowChips(items: Array(selected).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { item in
                withAnimation(decafAnimation) { _ = selected.remove(item) }
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filtered) { process in
                        ProcessRow(process: process, isSelected: selected.contains(process)) { toggle(process) }
                    }
                }
                .padding(8)
            }
            .frame(height: 336)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                InfoNote(symbol: "info.circle", text: "Decaf starts one watcher per selected PID.")
                Spacer()
                Button("Detach All Processes", role: .destructive) { controller.detachAll() }
                Button("Cancel") { dismiss() }
                Button { controller.attach(to: Array(selected)); dismiss() } label: { Label("Attach \(selected.count)", systemImage: "link") }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .background {
            LinearGradient(colors: [Color.white.opacity(0.12), Color.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .task { refresh() }
    }

    private func toggle(_ process: ProcessInfoItem) {
        withAnimation(decafAnimation) {
            if selected.contains(process) { selected.remove(process) } else { selected.insert(process) }
        }
    }

    private func refresh() {
        isLoading = true
        Task {
            allProcesses = await ProcessCatalog.load()
            isLoading = false
        }
    }
}

struct ProcessRow: View {
    let process: ProcessInfoItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ProcessGlyph(name: process.name)
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text("PID \(process.pid)  \(process.command)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(9)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FlowChips: View {
    let items: [ProcessInfoItem]
    let remove: (ProcessInfoItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 5) {
                        Text("\(item.name) \(item.pid)").font(.caption).lineLimit(1)
                        Button { remove(item) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: items.isEmpty ? 0 : 34)
        .animation(decafAnimation, value: items)
    }
}

struct OptionToggle: View {
    let symbol: String
    let title: String
    let flag: String
    let explanation: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $isOn) {
                    HStack(spacing: 8) {
                        Text(title)
                        Text(flag)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .tint(.accentColor)
                Text(explanation).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PreferenceHeader: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct GlassSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
    }
}

struct GlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(11)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct ProcessGlyph: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct InfoNote: View {
    var symbol = "info.circle"
    let text: String
    var color: Color = .secondary

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct StatusRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

struct CompactTimeStepper: View {
    @Binding var minutes: Int

    var body: some View {
        Stepper(value: $minutes, in: 0...(24 * 60 - 1), step: 15) {
            Text(ScheduleRule.timeText(minutes))
        }
            .monospacedDigit()
            .frame(width: 86)
    }
}

struct TimeStepper: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        HStack {
            if !title.isEmpty { Text(title) }
            Spacer()
            Stepper("\(hourText):\(minuteText)", value: $minutes, in: 0...(24 * 60 - 1), step: 15)
                .monospacedDigit()
                .frame(width: 140)
        }
    }

    private var hourText: String { String(format: "%02d", minutes / 60) }
    private var minuteText: String { String(format: "%02d", minutes % 60) }
}

private extension ProfileKind {
    var symbolName: String {
        switch self {
        case .work: "display"
        case .night: "moon"
        case .attached: "link.circle"
        }
    }
}
