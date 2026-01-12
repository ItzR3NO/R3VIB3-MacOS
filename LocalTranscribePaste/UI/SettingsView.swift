import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private let deviceProvider: AudioDeviceProviding
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let permissions: PermissionsManaging
    private let statusBarController: StatusBarControlling
    @ObservedObject private var settings: SettingsStore
    @State private var launchAtLoginEnabled: Bool

    private var devices: [AudioInputDevice] {
        deviceProvider.inputDevices()
    }

    private var selectedDevice: AudioInputDevice? {
        devices.first { $0.uid == settings.inputDeviceUID }
    }

    private var defaultChannels: Int {
        deviceProvider.defaultInputDeviceID()
            .map { deviceProvider.inputChannelCount(deviceID: $0) } ?? 0
    }

    private var channelCount: Int {
        selectedDevice?.channels ?? defaultChannels
    }

    private var launchSupported: Bool {
        launchAtLoginManager.isSupported
    }

    init(
        settings: SettingsStore,
        permissions: PermissionsManaging,
        statusBarController: StatusBarControlling,
        deviceProvider: AudioDeviceProviding = SystemAudioDeviceProvider(),
        launchAtLoginManager: LaunchAtLoginManaging = LaunchAtLoginManager.shared
    ) {
        self._settings = ObservedObject(wrappedValue: settings)
        self.permissions = permissions
        self.statusBarController = statusBarController
        self.deviceProvider = deviceProvider
        self.launchAtLoginManager = launchAtLoginManager
        _launchAtLoginEnabled = State(initialValue: launchAtLoginManager.isEnabled())
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
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled()
        }
    }

    @ViewBuilder
    private var formBody: some View {
        microphoneSection
        transcriptionSection
        pasteSection
        startupSection
        hotkeysSection
    }

    private var microphoneSection: some View {
        Section("Microphone input") {
            labeledRow("Input Device") {
                Picker("", selection: $settings.inputDeviceUID) {
                    Text("System Default").tag("system")
                    ForEach(devices) { device in
                        Text("\(device.name) (\(device.channels) ch)").tag(device.uid)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
            }
            labeledRow("Input Channel") {
                Picker("", selection: $settings.inputChannelIndex) {
                    Text("Auto").tag(0)
                    ForEach(1...max(channelCount, 1), id: \.self) { channel in
                        Text("Channel \(channel)").tag(channel)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
            }
            Text("If your default input is multi-channel, choose a specific mic here.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var transcriptionSection: some View {
        Section("Transcription model") {
            labeledRow("Model path") {
                HStack {
                    TextField("/path/to/model.bin", text: $settings.modelPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Choose") {
                        chooseModel()
                    }
                }
            }
            Text("Default: \(SettingsStore.defaultModelPath().path)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var pasteSection: some View {
        Section("Paste behavior") {
            Picker("Paste Mode", selection: $settings.pasteMode) {
                Text("Cmd+V").tag(PasteMode.cmdV)
                Text("Ctrl+V").tag(PasteMode.ctrlV)
                Text("Type").tag(PasteMode.type)
            }
            .pickerStyle(SegmentedPickerStyle())
            Toggle("Copy transcript to clipboard after transcription", isOn: $settings.autoCopyOnTranscription)
            Toggle("Show transcript popover after transcription", isOn: $settings.showTranscriptPopover)
            Text("Type mode injects characters when paste is blocked.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var startupSection: some View {
        Section("Startup") {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { newValue in
                    if launchAtLoginManager.setEnabled(newValue) {
                        launchAtLoginEnabled = newValue
                    } else {
                        launchAtLoginEnabled = launchAtLoginManager.isEnabled()
                    }
                }
            ))
            .disabled(!launchSupported)
            if !launchSupported {
                Text("Requires macOS 13 or later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var hotkeysSection: some View {
        Section("Hotkeys") {
            labeledRow("Toggle Dictation") {
                HotkeyRecorderView(hotkey: $settings.toggleHotkey, permissions: permissions, statusBarController: statusBarController)
            }
            labeledRow("Hold to Dictate") {
                HotkeyRecorderView(hotkey: $settings.holdHotkey, permissions: permissions, statusBarController: statusBarController)
            }
            labeledRow("Paste Last Transcript") {
                HotkeyRecorderView(hotkey: $settings.pasteHotkey, permissions: permissions, statusBarController: statusBarController)
            }
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

    private func chooseModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "bin")].compactMap { $0 }
        if panel.runModal() == .OK, let url = panel.url {
            settings.modelPath = url.path
        }
    }
}
