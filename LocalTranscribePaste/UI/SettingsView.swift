import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = AppState.shared.settings
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled()

    var body: some View {
        let devices = AudioDeviceManager.inputDevices()
        let selectedDevice = devices.first { $0.uid == settings.inputDeviceUID }
        let defaultChannels = AudioDeviceManager.defaultInputDeviceID().map { AudioDeviceManager.inputChannelCount(deviceID: $0) } ?? 0
        let channelCount = selectedDevice?.channels ?? defaultChannels
        let launchSupported = LaunchAtLoginManager.shared.isSupported
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(label: Text("Microphone input")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Input Device", selection: $settings.inputDeviceUID) {
                            Text("System Default").tag("system")
                            ForEach(devices) { device in
                                Text("\(device.name) (\(device.channels) ch)").tag(device.uid)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Picker("Input Channel", selection: $settings.inputChannelIndex) {
                            Text("Auto").tag(0)
                            ForEach(1...max(channelCount, 1), id: \.self) { channel in
                                Text("Channel \(channel)").tag(channel)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("If your default input is multi-channel, choose a specific mic here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                GroupBox(label: Text("Transcription model")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model path")
                            .font(.subheadline)
                        HStack {
                            TextField("/path/to/model.bin", text: $settings.modelPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Choose") {
                                chooseModel()
                            }
                        }
                        Text("Default: \(SettingsStore.defaultModelPath().path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                GroupBox(label: Text("Paste behavior")) {
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding(8)
                }

                GroupBox(label: Text("Startup")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Launch at login", isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { newValue in
                                if LaunchAtLoginManager.shared.setEnabled(newValue) {
                                    launchAtLoginEnabled = newValue
                                } else {
                                    launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled()
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
                    .padding(8)
                }

                GroupBox(label: Text("Hotkeys")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Toggle Dictation")
                                .frame(width: 160, alignment: .leading)
                            HotkeyRecorderView(hotkey: $settings.toggleHotkey)
                        }
                        HStack {
                            Text("Hold to Dictate")
                                .frame(width: 160, alignment: .leading)
                            HotkeyRecorderView(hotkey: $settings.holdHotkey)
                        }
                        HStack {
                            Text("Paste Last Transcript")
                                .frame(width: 160, alignment: .leading)
                            HotkeyRecorderView(hotkey: $settings.pasteHotkey)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled()
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
