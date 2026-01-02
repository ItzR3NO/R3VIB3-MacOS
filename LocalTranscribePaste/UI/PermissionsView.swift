import SwiftUI

struct PermissionsView: View {
    @State private var micAuthorized = AppState.shared.permissions.isMicrophoneAuthorized
    @State private var accessibilityAuthorized = AppState.shared.permissions.isAccessibilityAuthorized
    @State private var micStatus: MicrophoneAuthorizationStatus = AppState.shared.permissions.microphoneStatus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(label: Text("Permissions status")) {
                    VStack(alignment: .leading, spacing: 12) {
                        statusRow(title: "Microphone", isAuthorized: micAuthorized)
                        statusRow(title: "Accessibility", isAuthorized: accessibilityAuthorized)
                    }
                    .padding(8)
                }

                GroupBox(label: Text("Actions")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Request Microphone Permission") {
                            AppState.shared.permissions.requestMicrophoneAccess { granted in
                                refresh()
                                if !granted {
                                    AppState.shared.permissions.openMicrophoneSettings()
                                }
                            }
                        }
                        Button("Request Accessibility Permission") {
                            AppState.shared.permissions.requestAccessibilityAccess()
                            refresh()
                        }
                        Button("Refresh Status") {
                            refresh()
                        }
                    }
                    .padding(8)
                }

                GroupBox(label: Text("How to enable")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Settings > Privacy & Security > Microphone")
                        Text("System Settings > Privacy & Security > Accessibility")
                        Text("If R3VIB3 is listed but off, toggle it on (macOS won’t re-prompt).")
                        Text("Enable R3VIB3, then restart the app if needed.")
                        if let bundleID = Bundle.main.bundleIdentifier {
                            Text("Bundle ID: \(bundleID)")
                        }
                        Text("App path: \(Bundle.main.bundlePath)")
                    }
                    .font(.caption)
                    .padding(8)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { refresh() }
    }

    private func refresh() {
        micAuthorized = AppState.shared.permissions.isMicrophoneAuthorized
        accessibilityAuthorized = AppState.shared.permissions.isAccessibilityAuthorized
        micStatus = AppState.shared.permissions.microphoneStatus
        AppState.shared.permissions.logCurrentStatus()
        if accessibilityAuthorized {
            HoldHotkeyManager.shared.restartIfNeeded()
        }
    }

    @ViewBuilder
    private func statusRow(title: String, isAuthorized: Bool) -> some View {
        HStack {
            Text(title)
                .frame(width: 140, alignment: .leading)
            Text(isAuthorized ? "Authorized" : "Not authorized")
                .foregroundColor(isAuthorized ? .green : .red)
        }
    }
}
