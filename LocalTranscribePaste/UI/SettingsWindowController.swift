import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init() {
        let view = SettingsView().environmentObject(AppState.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 520, height: 360))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PermissionsWindowController: NSWindowController {
    init() {
        let view = PermissionsView().environmentObject(AppState.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Permissions checklist"
        window.setContentSize(NSSize(width: 520, height: 360))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
