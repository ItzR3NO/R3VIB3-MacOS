import SwiftUI

struct PermissionsView: View {
    private let permissions: PermissionsManaging
    private let holdHotkeyManager: HoldHotkeyManaging
    private let bundle: BundleProviding
    @State private var micAuthorized: Bool
    @State private var accessibilityAuthorized: Bool
    @State private var micStatus: MicrophoneAuthorizationStatus

    init(
        permissions: PermissionsManaging,
        holdHotkeyManager: HoldHotkeyManaging = HoldHotkeyManager.shared,
        bundle: BundleProviding = MainBundleProvider()
    ) {
        self.permissions = permissions
        self.holdHotkeyManager = holdHotkeyManager
        self.bundle = bundle
        _micAuthorized = State(initialValue: permissions.isMicrophoneAuthorized)
        _accessibilityAuthorized = State(initialValue: permissions.isAccessibilityAuthorized)
        _micStatus = State(initialValue: permissions.microphoneStatus)
    }

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                Form {
                    formBody
                }
                .formStyle(.grouped)
            } else {
                Form {
                    formBody
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { refresh() }
    }

    @ViewBuilder
    private var formBody: some View {
        statusSection
        actionsSection
        helpSection
    }

    private var statusSection: some View {
        Section("Permissions status") {
            statusRow(title: "Microphone", isAuthorized: micAuthorized)
            statusRow(title: "Accessibility", isAuthorized: accessibilityAuthorized)
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Request Microphone Permission") {
                permissions.requestMicrophoneAccess { granted in
                    refresh()
                    if !granted {
                        permissions.openMicrophoneSettings()
                    }
                }
            }
            Button("Request Accessibility Permission") {
                permissions.requestAccessibilityAccess()
                refresh()
            }
            Button("Refresh Status") {
                refresh()
            }
        }
    }

    private var helpSection: some View {
        Section("How to enable") {
            Text("System Settings > Privacy & Security > Microphone")
            Text("System Settings > Privacy & Security > Accessibility")
            Text("If R3VIB3 is missing or stuck, remove it and re-add in Accessibility.")
            Text("Enable R3VIB3, then restart the app if needed.")
            if let bundleID = bundle.bundleIdentifier {
                Text("Bundle ID: \(bundleID)")
            }
            Text("App path: \(bundle.bundlePath)")
        }
        .font(.caption)
    }

    private func refresh() {
        micAuthorized = permissions.isMicrophoneAuthorized
        accessibilityAuthorized = permissions.isAccessibilityAuthorized
        micStatus = permissions.microphoneStatus
        permissions.logCurrentStatus()
        if accessibilityAuthorized {
            holdHotkeyManager.restartIfNeeded()
        }
    }

    @ViewBuilder
    private func statusRow(title: String, isAuthorized: Bool) -> some View {
        labeledRow(title) {
            Text(isAuthorized ? "Authorized" : "Not authorized")
                .foregroundColor(isAuthorized ? .green : .red)
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 13.0, *) {
            LabeledContent(title) {
                content()
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .frame(width: 160, alignment: .leading)
                content()
            }
        }
    }
}
