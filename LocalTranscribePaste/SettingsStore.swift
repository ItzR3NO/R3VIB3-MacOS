import Foundation
import Combine

enum PasteMode: String, Codable, CaseIterable {
    case cmdV
    case ctrlV
    case type
}

final class SettingsStore: ObservableObject {
    @Published var modelPath: String {
        didSet { saveModelPath() }
    }

    @Published var pasteMode: PasteMode {
        didSet { savePasteMode() }
    }

    @Published var toggleHotkey: Hotkey {
        didSet { saveHotkey(toggleHotkey, key: Keys.toggleHotkey) }
    }

    @Published var pasteHotkey: Hotkey {
        didSet { saveHotkey(pasteHotkey, key: Keys.pasteHotkey) }
    }

    @Published var holdHotkey: Hotkey {
        didSet { saveHotkey(holdHotkey, key: Keys.holdHotkey) }
    }

    @Published var screenshotHotkey: Hotkey {
        didSet { saveHotkey(screenshotHotkey, key: Keys.screenshotHotkey) }
    }

    @Published var inputDeviceUID: String {
        didSet { saveInputDeviceUID() }
    }

    @Published var inputChannelIndex: Int {
        didSet { saveInputChannelIndex() }
    }

    @Published var autoCopyOnTranscription: Bool {
        didSet { saveAutoCopyOnTranscription() }
    }

    @Published var showTranscriptPopover: Bool {
        didSet { saveShowTranscriptPopover() }
    }

    private let defaults: KeyValueStoring
    private let fileSystem: FileSystem
    private let deviceProvider: AudioDeviceProviding

    init(
        defaults: KeyValueStoring = UserDefaultsStore(),
        fileSystem: FileSystem = SystemFileSystem(),
        deviceProvider: AudioDeviceProviding = SystemAudioDeviceProvider()
    ) {
        self.defaults = defaults
        self.fileSystem = fileSystem
        self.deviceProvider = deviceProvider

        let defaultModel = SettingsStore.defaultModelPath(fileSystem: fileSystem).path
        modelPath = defaults.string(forKey: Keys.modelPath) ?? defaultModel
        pasteMode = PasteMode(rawValue: defaults.string(forKey: Keys.pasteMode) ?? "cmdV") ?? .cmdV
        toggleHotkey = SettingsStore.loadHotkey(key: Keys.toggleHotkey, defaults: defaults) ?? Hotkey.defaultToggle
        pasteHotkey = SettingsStore.loadHotkey(key: Keys.pasteHotkey, defaults: defaults) ?? Hotkey.defaultPaste
        holdHotkey = SettingsStore.loadHotkey(key: Keys.holdHotkey, defaults: defaults) ?? Hotkey.defaultHold
        screenshotHotkey = SettingsStore.loadHotkey(key: Keys.screenshotHotkey, defaults: defaults) ?? Hotkey.defaultScreenshot
        inputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID) ?? SettingsStore.defaultInputDeviceUID(deviceProvider: deviceProvider)
        inputChannelIndex = defaults.integer(forKey: Keys.inputChannelIndex)
        autoCopyOnTranscription = defaults.bool(forKey: Keys.autoCopyOnTranscription)
        showTranscriptPopover = defaults.object(forKey: Keys.showTranscriptPopover) as? Bool ?? true
    }

    static func defaultModelPath(fileSystem: FileSystem = SystemFileSystem()) -> URL {
        let modelsDir = ensureModelsDirectory(fileSystem: fileSystem)
        return modelsDir.appendingPathComponent("ggml-base.en.bin")
    }

    static func ensureModelsDirectory(fileSystem: FileSystem = SystemFileSystem()) -> URL {
        let appSupport = fileSystem.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("R3VIB3/Models", isDirectory: true)
        if fileSystem.fileExists(atPath: modelsDir.path) {
            return modelsDir
        }
        let legacyDir = appSupport.appendingPathComponent("LocalTranscribePaste/Models", isDirectory: true)
        if fileSystem.fileExists(atPath: legacyDir.path) {
            return legacyDir
        }
        try? fileSystem.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }

    private func saveModelPath() {
        defaults.set(modelPath, forKey: Keys.modelPath)
    }

    private func savePasteMode() {
        defaults.set(pasteMode.rawValue, forKey: Keys.pasteMode)
    }

    private func saveInputDeviceUID() {
        defaults.set(inputDeviceUID, forKey: Keys.inputDeviceUID)
    }

    private func saveInputChannelIndex() {
        defaults.set(inputChannelIndex, forKey: Keys.inputChannelIndex)
    }

    private func saveAutoCopyOnTranscription() {
        defaults.set(autoCopyOnTranscription, forKey: Keys.autoCopyOnTranscription)
    }

    private func saveShowTranscriptPopover() {
        defaults.set(showTranscriptPopover, forKey: Keys.showTranscriptPopover)
    }

    private func saveHotkey(_ hotkey: Hotkey, key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(hotkey) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadHotkey(key: String, defaults: KeyValueStoring) -> Hotkey? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Hotkey.self, from: data)
    }

    private enum Keys {
        static let modelPath = "modelPath"
        static let pasteMode = "pasteMode"
        static let toggleHotkey = "toggleHotkey"
        static let pasteHotkey = "pasteHotkey"
        static let holdHotkey = "holdHotkey"
        static let screenshotHotkey = "screenshotHotkey"
        static let inputDeviceUID = "inputDeviceUID"
        static let inputChannelIndex = "inputChannelIndex"
        static let autoCopyOnTranscription = "autoCopyOnTranscription"
        static let showTranscriptPopover = "showTranscriptPopover"
    }

    static func defaultInputDeviceUID(deviceProvider: AudioDeviceProviding = SystemAudioDeviceProvider()) -> String {
        guard let defaultID = deviceProvider.defaultInputDeviceID() else { return "system" }
        let channels = deviceProvider.inputChannelCount(deviceID: defaultID)
        if channels > 2, let builtIn = deviceProvider.builtInMicrophoneDeviceID(),
           let uid = deviceProvider.deviceUID(deviceID: builtIn) {
            return uid
        }
        return "system"
    }
}
