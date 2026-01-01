import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private weak var appState: AppState?
    private let recordingIndicator = RecordingIndicatorWindowController()
    private var indicatorMode: IndicatorMode?

    private var toggleItem: NSMenuItem?
    private var pasteItem: NSMenuItem?
    private var settingsWindow: SettingsWindowController?
    private var permissionsWindow: PermissionsWindowController?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupMenu()
    }

    func updateRecordingIndicator(isRecording: Bool) {
        statusItem.button?.appearsDisabled = isRecording
        toggleItem?.title = isRecording ? "Stop dictation" : "Start dictation"
        if isRecording {
            indicatorMode = .recording
            recordingIndicator.show(mode: .recording)
        } else if indicatorMode == .recording {
            indicatorMode = nil
            recordingIndicator.hide()
        }
    }

    func showPasteReadyIndicator() {
        indicatorMode = .pasteReady
        recordingIndicator.show(mode: .pasteReady)
    }

    func clearPasteReadyIndicator() {
        guard indicatorMode == .pasteReady else { return }
        indicatorMode = nil
        recordingIndicator.hide()
    }

    func showTranscript(text: String) {
        showPopover(content: TranscriptPopoverView(text: text, isMessageOnly: false))
    }

    func showMessage(_ message: String) {
        showPopover(content: TranscriptPopoverView(text: message, isMessageOnly: true))
    }

    func showPermissions() {
        if permissionsWindow == nil {
            permissionsWindow = PermissionsWindowController()
        }
        permissionsWindow?.showWindow(nil)
        permissionsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        if let image = NSImage(named: "StatusIcon") {
            image.isTemplate = false
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "R3"
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Start dictation", action: #selector(toggleDictation), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        toggleItem = toggle

        let paste = NSMenuItem(title: "Paste last transcript", action: #selector(pasteLast), keyEquivalent: "")
        paste.target = self
        menu.addItem(paste)
        pasteItem = paste

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Permissions checklist", action: #selector(openPermissions), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func showPopover<Content: View>(content: Content) {
        guard let button = statusItem.button else { return }
        let hosting = NSHostingController(rootView: content.environmentObject(AppState.shared))
        popover.behavior = .transient
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func toggleDictation() {
        appState?.toggleDictation()
    }

    @objc private func pasteLast() {
        appState?.pasteLastTranscript()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func openPermissions() {
        showPermissions()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
