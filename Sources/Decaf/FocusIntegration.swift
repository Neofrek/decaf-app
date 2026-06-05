import Foundation
import Intents

@MainActor
final class FocusIntegration: ObservableObject {
    @Published private(set) var permissionStatus: FocusPermissionStatus = .unable
    @Published private(set) var isFocused: Bool?
    @Published private(set) var message = "Shared Focus Status is unavailable or permission was denied."
    @Published private(set) var detail = "Apple does not provide a public macOS API for Decaf to read the active Focus name or Apple Sleep schedule."

    var isSupported: Bool {
        if #available(macOS 12.0, *) { true } else { false }
    }

    func refresh() {
        guard isSupported else {
            permissionStatus = .notSupported
            isFocused = nil
            message = "Shared Focus Status is not supported on this macOS version."
            detail = "Core scheduling and manual modes still work."
            return
        }
        if #available(macOS 12.0, *) {
            let center = INFocusStatusCenter.default
            switch center.authorizationStatus {
            case .authorized:
                permissionStatus = .available
                isFocused = center.focusStatus.isFocused
                if isFocused == nil {
                    permissionStatus = .unable
                    message = "Shared Focus Status is unavailable."
                    detail = "Enable Focus Status sharing in macOS and make sure Decaf has permission."
                } else if isFocused == true {
                    message = "Shared Focus Status is active."
                    detail = "Decaf will use the existing Night Mode settings before schedule rules while this remains active."
                } else {
                    message = "Shared Focus Status is inactive for Decaf."
                    detail = "A Focus may still be active. macOS can report inactive when this app is allowed notifications or Focus Status is not shared with it."
                }
            case .denied, .restricted:
                permissionStatus = .denied
                isFocused = nil
                message = "Shared Focus Status is unavailable or permission was denied."
                detail = "Decaf cannot use Focus for Night Mode until permission is allowed."
            case .notDetermined:
                permissionStatus = .notDetermined
                isFocused = nil
                message = "Focus permission has not been requested."
                detail = "Request permission to let Decaf read Apple's Shared Focus Status signal."
            @unknown default:
                permissionStatus = .unable
                isFocused = nil
                message = "Shared Focus Status is unavailable or permission was denied."
                detail = "Core scheduling and manual modes still work."
            }
        }
    }

    func requestPermission(completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard isSupported else {
            refresh()
            completion?()
            return
        }
        if #available(macOS 12.0, *) {
            INFocusStatusCenter.default.requestAuthorization { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                    completion?()
                }
            }
        }
    }
}
