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

    private let defaults = UserDefaults.standard

    init() {
        let defaultModel = SettingsStore.defaultModelPath().path
        modelPath = defaults.string(forKey: Keys.modelPath) ?? defaultModel
        pasteMode = PasteMode(rawValue: defaults.string(forKey: Keys.pasteMode) ?? "cmdV") ?? .cmdV
        toggleHotkey = SettingsStore.loadHotkey(key: Keys.toggleHotkey) ?? Hotkey.defaultToggle
        pasteHotkey = SettingsStore.loadHotkey(key: Keys.pasteHotkey) ?? Hotkey.defaultPaste
        holdHotkey = SettingsStore.loadHotkey(key: Keys.holdHotkey) ?? Hotkey.defaultHold
        inputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID) ?? SettingsStore.defaultInputDeviceUID()
        inputChannelIndex = defaults.integer(forKey: Keys.inputChannelIndex)
        autoCopyOnTranscription = defaults.bool(forKey: Keys.autoCopyOnTranscription)
        showTranscriptPopover = defaults.object(forKey: Keys.showTranscriptPopover) as? Bool ?? true
    }

    static func defaultModelPath() -> URL {
        let modelsDir = ensureModelsDirectory()
        return modelsDir.appendingPathComponent("ggml-base.en.bin")
    }

    static func ensureModelsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("R3VIB3/Models", isDirectory: true)
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            return modelsDir
        }
        let legacyDir = appSupport.appendingPathComponent("LocalTranscribePaste/Models", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyDir.path) {
            return legacyDir
        }
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
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

    private static func loadHotkey(key: String) -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Hotkey.self, from: data)
    }

    private enum Keys {
        static let modelPath = "modelPath"
        static let pasteMode = "pasteMode"
        static let toggleHotkey = "toggleHotkey"
        static let pasteHotkey = "pasteHotkey"
        static let holdHotkey = "holdHotkey"
        static let inputDeviceUID = "inputDeviceUID"
        static let inputChannelIndex = "inputChannelIndex"
        static let autoCopyOnTranscription = "autoCopyOnTranscription"
        static let showTranscriptPopover = "showTranscriptPopover"
    }

    static func defaultInputDeviceUID() -> String {
        guard let defaultID = AudioDeviceManager.defaultInputDeviceID() else { return "system" }
        let channels = AudioDeviceManager.inputChannelCount(deviceID: defaultID)
        if channels > 2, let builtIn = AudioDeviceManager.builtInMicrophoneDeviceID(),
           let uid = AudioDeviceManager.deviceUID(deviceID: builtIn) {
            return uid
        }
        return "system"
    }
}
