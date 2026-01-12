import Foundation
import CoreGraphics

protocol AudioCapturing {
    func startRecording(preferredDeviceUID: String?, preferredChannelIndex: Int) throws
    func stopRecording() throws -> URL
}

protocol TranscriptionManaging {
    func transcribe(audioURL: URL, modelPath: String, completion: @escaping (Result<String, Error>) -> Void)
}

protocol PasteManaging {
    func copyToClipboard(text: String)
    func paste(text: String, mode: PasteMode)
}

protocol PermissionsManaging {
    var isMicrophoneAuthorized: Bool { get }
    var isAccessibilityAuthorized: Bool { get }
    var microphoneStatus: MicrophoneAuthorizationStatus { get }
    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void)
    func openMicrophoneSettings()
    func requestAccessibilityAccess()
    func resetAccessibilityPermissionIfNeeded()
    func logCurrentStatus()
}

protocol StatusBarControlling {
    func updateRecordingIndicator(isRecording: Bool)
    func showPasteReadyIndicator()
    func clearPasteReadyIndicator()
    func showTranscript(text: String)
    func showMessage(_ message: String)
    func showPermissions()
    func showSettings()
}

protocol HotkeyManaging {
    var onToggleDictation: (() -> Void)? { get set }
    var onPasteLastTranscript: (() -> Void)? { get set }
    func registerHotkeys(toggle: Hotkey?, paste: Hotkey?)
}

protocol HoldHotkeyManaging {
    var onToggle: (() -> Void)? { get set }
    var onPaste: (() -> Void)? { get set }
    var onHoldStart: (() -> Void)? { get set }
    var onHoldEnd: (() -> Void)? { get set }
    var onPasteKeystroke: ((UInt32, CGEventFlags) -> Void)? { get set }
    func updateHotkeys(toggle: Hotkey, paste: Hotkey, hold: Hotkey)
    func updateHoldHotkey(_ hotkey: Hotkey)
    func updateToggleHotkey(_ hotkey: Hotkey)
    func updatePasteHotkey(_ hotkey: Hotkey)
    func start()
    func restartIfNeeded()
}

protocol LaunchAtLoginManaging {
    var isSupported: Bool { get }
    func isEnabled() -> Bool
    @discardableResult func setEnabled(_ enabled: Bool) -> Bool
}

extension AudioCaptureManager: AudioCapturing {}
extension TranscriptionManager: TranscriptionManaging {}
extension PasteManager: PasteManaging {}
extension PermissionsManager: PermissionsManaging {}
extension StatusBarController: StatusBarControlling {}
extension HotkeyManager: HotkeyManaging {}
extension HoldHotkeyManager: HoldHotkeyManaging {}
extension LaunchAtLoginManager: LaunchAtLoginManaging {}
