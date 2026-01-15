import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(appState: AppState = AppState.shared) {
        let view = SettingsView(
            settings: appState.settings,
            permissions: appState.permissions,
            statusBarController: appState.statusBarController
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 520, height: 440))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PermissionsWindowController: NSWindowController {
    init(appState: AppState = AppState.shared) {
        let view = PermissionsView(permissions: appState.permissions)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Permissions checklist"
        window.setContentSize(NSSize(width: 520, height: 440))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
