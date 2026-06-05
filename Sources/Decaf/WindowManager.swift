import AppKit
import SwiftUI

@MainActor
final class WindowManager {
    private var preferencesWindow: NSWindow?
    private var attachWindow: NSWindow?
    private var preferencesDelegate: WindowDelegate?
    private var attachDelegate: WindowDelegate?

    func showPreferences(controller: DecafController) {
        if let preferencesWindow {
            bringToFront(preferencesWindow)
            return
        }
        let window = makeWindow(
            title: "Decaf Preferences",
            size: NSSize(width: 820, height: 660),
            minSize: NSSize(width: 720, height: 540),
            maxSize: NSSize(width: 1040, height: 860),
            content: PreferencesView().environmentObject(controller)
        )
        let delegate = WindowDelegate { [weak self] in
            self?.preferencesWindow = nil
            self?.preferencesDelegate = nil
        }
        preferencesDelegate = delegate
        preferencesWindow = window
        window.delegate = delegate
        bringToFront(window)
    }

    func showAttach(controller: DecafController) {
        if let attachWindow {
            bringToFront(attachWindow)
            return
        }
        let window = makeWindow(
            title: "Attach to Processes",
            size: NSSize(width: 700, height: 600),
            minSize: NSSize(width: 620, height: 480),
            maxSize: NSSize(width: 940, height: 760),
            content: AttachProcessesView().environmentObject(controller)
        )
        let delegate = WindowDelegate { [weak self] in
            self?.attachWindow = nil
            self?.attachDelegate = nil
        }
        attachDelegate = delegate
        attachWindow = window
        window.delegate = delegate
        bringToFront(window)
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, minSize: NSSize, maxSize: NSSize, content: Content) -> NSWindow {
        let hosting = NSHostingController(rootView: content)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = []
        }

        let window = DecafUtilityWindow(contentViewController: hosting)
        window.title = title
        window.setContentSize(size)
        window.contentMinSize = minSize
        window.contentMaxSize = maxSize
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        return window
    }

    private func bringToFront(_ window: NSWindow) {
        window.deminiaturize(nil)
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
        DispatchQueue.main.async {
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
        }
    }
}

private final class DecafUtilityWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
