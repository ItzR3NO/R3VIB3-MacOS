import Foundation
import Combine
import os
import AppKit
import Carbon

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var lastTranscript: String = ""
    @Published var lastAudioFileURL: URL?
    @Published var activeRecordingMode: RecordingMode = .none
    @Published var isPasteReady: Bool = false

    let settings = SettingsStore()
    let audioCapture = AudioCaptureManager()
    let transcriptionManager = TranscriptionManager()
    let pasteManager = PasteManager()
    let permissions = PermissionsManager()

    lazy var statusBarController = StatusBarController(appState: self)

    private var cancellables = Set<AnyCancellable>()
    private var accessibilityObserver: Any?

    private init() {
        configureHotkeys()
        observeSettings()
    }

    func start() {
        _ = statusBarController
        permissions.logCurrentStatus()
        if !permissions.isAccessibilityAuthorized {
            permissions.requestAccessibilityAccess()
        }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.permissions.isAccessibilityAuthorized {
                HoldHotkeyManager.shared.restartIfNeeded()
            }
        }
    }

    private func configureHotkeys() {
        HoldHotkeyManager.shared.onToggle = { [weak self] in
            guard let self = self else { return }
            if self.settings.toggleHotkey.requiresEventTap {
                self.toggleDictation()
            }
        }
        HoldHotkeyManager.shared.onPasteKeystroke = { [weak self] keyCode, flags in
            self?.handlePasteKeystroke(keyCode: keyCode, flags: flags)
        }
        HoldHotkeyManager.shared.onPaste = { [weak self] in
            guard let self = self else { return }
            if self.settings.pasteHotkey.requiresEventTap {
                self.pasteLastTranscript()
            }
        }
        HoldHotkeyManager.shared.onHoldStart = { [weak self] in
            self?.startHoldRecording()
        }
        HoldHotkeyManager.shared.onHoldEnd = { [weak self] in
            self?.stopHoldRecording()
        }
        HoldHotkeyManager.shared.updateHotkeys(toggle: settings.toggleHotkey, paste: settings.pasteHotkey, hold: settings.holdHotkey)
        HoldHotkeyManager.shared.start()

        HotkeyManager.shared.onToggleDictation = { [weak self] in
            guard let self = self else { return }
            if !self.settings.toggleHotkey.requiresEventTap {
                self.toggleDictation()
            }
        }
        HotkeyManager.shared.onPasteLastTranscript = { [weak self] in
            guard let self = self else { return }
            if !self.settings.pasteHotkey.requiresEventTap {
                self.pasteLastTranscript()
            }
        }
        updateCarbonHotkeys()
    }

    private func observeSettings() {
        settings.$toggleHotkey.sink { hotkey in
            HoldHotkeyManager.shared.updateToggleHotkey(hotkey)
            self.updateCarbonHotkeys()
        }.store(in: &cancellables)

        settings.$pasteHotkey.sink { hotkey in
            HoldHotkeyManager.shared.updatePasteHotkey(hotkey)
            self.updateCarbonHotkeys()
        }.store(in: &cancellables)

        settings.$holdHotkey.sink { hotkey in
            HoldHotkeyManager.shared.updateHoldHotkey(hotkey)
        }.store(in: &cancellables)
    }

    private func handlePasteKeystroke(keyCode: UInt32, flags: CGEventFlags) {
        guard isPasteReady else { return }
        guard keyCode == UInt32(kVK_ANSI_V) else { return }
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            isPasteReady = false
            statusBarController.clearPasteReadyIndicator()
        }
    }

    private func updateCarbonHotkeys() {
        let toggle = settings.toggleHotkey.requiresEventTap ? nil : settings.toggleHotkey
        let paste = settings.pasteHotkey.requiresEventTap ? nil : settings.pasteHotkey
        HotkeyManager.shared.registerHotkeys(toggle: toggle, paste: paste)
    }

    func toggleDictation() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.toggleDictation()
            }
            return
        }
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startRecording()
            }
            return
        }
        guard permissions.isMicrophoneAuthorized else {
            statusBarController.showPermissions()
            Log.audio.warning("Microphone permission missing")
            return
        }
        isPasteReady = false
        statusBarController.clearPasteReadyIndicator()
        activeRecordingMode = .toggle
        do {
            try audioCapture.startRecording(
                preferredDeviceUID: settings.inputDeviceUID,
                preferredChannelIndex: settings.inputChannelIndex
            )
            isRecording = true
            statusBarController.updateRecordingIndicator(isRecording: true)
            Log.audio.info("Recording started")
        } catch {
            Log.audio.error("Failed to start recording: \(error.localizedDescription)")
            statusBarController.showMessage("Failed to start recording")
        }
    }

    private func stopRecordingAndTranscribe() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecordingAndTranscribe()
            }
            return
        }
        do {
            let audioURL = try audioCapture.stopRecording()
            isRecording = false
            statusBarController.updateRecordingIndicator(isRecording: false)
            Log.audio.info("Recording stopped")
            transcribe(audioURL: audioURL)
        } catch {
            isRecording = false
            statusBarController.updateRecordingIndicator(isRecording: false)
            Log.audio.error("Failed to stop recording: \(error.localizedDescription)")
            statusBarController.showMessage("Failed to stop recording")
            activeRecordingMode = .none
        }
    }

    private func startHoldRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startHoldRecording()
            }
            return
        }
        guard !isRecording else { return }
        guard permissions.isMicrophoneAuthorized else {
            statusBarController.showPermissions()
            return
        }
        isPasteReady = false
        statusBarController.clearPasteReadyIndicator()
        activeRecordingMode = .hold
        do {
            try audioCapture.startRecording(
                preferredDeviceUID: settings.inputDeviceUID,
                preferredChannelIndex: settings.inputChannelIndex
            )
            isRecording = true
            statusBarController.updateRecordingIndicator(isRecording: true)
            Log.audio.info("Recording started (hold)")
        } catch {
            Log.audio.error("Failed to start recording (hold): \(error.localizedDescription)")
            statusBarController.showMessage("Failed to start recording")
            activeRecordingMode = .none
        }
    }

    private func stopHoldRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stopHoldRecording()
            }
            return
        }
        guard isRecording, activeRecordingMode == .hold else { return }
        stopRecordingAndTranscribe()
        activeRecordingMode = .none
    }

    func transcribe(audioURL: URL) {
        guard permissions.isMicrophoneAuthorized else {
            statusBarController.showPermissions()
            return
        }
        isPasteReady = false
        statusBarController.clearPasteReadyIndicator()
        isTranscribing = true
        lastAudioFileURL = audioURL
        Log.transcription.info("Transcription started")
        transcriptionManager.transcribe(audioURL: audioURL, modelPath: settings.modelPath) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isTranscribing = false
                switch result {
                case .success(let text):
                    self.lastTranscript = text
                    Log.transcription.info("Transcription completed")
                    if self.settings.autoCopyOnTranscription {
                        self.pasteManager.copyToClipboard(text: text)
                        Log.paste.info("Copied transcript to clipboard")
                    }
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.isPasteReady = true
                        self.statusBarController.showPasteReadyIndicator()
                    }
                    if self.settings.showTranscriptPopover {
                        self.statusBarController.showTranscript(text: text)
                    }
                case .failure(let error):
                    Log.transcription.error("Transcription failed: \(error.localizedDescription)")
                    self.statusBarController.showMessage(self.describeTranscriptionError(error))
                }
            }
        }
    }

    func retryTranscription() {
        guard let audioURL = lastAudioFileURL else {
            statusBarController.showMessage("No audio to retry")
            return
        }
        transcribe(audioURL: audioURL)
    }

    func pasteLastTranscript() {
        guard !lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusBarController.showMessage("No transcript")
            return
        }
        guard permissions.isAccessibilityAuthorized else {
            statusBarController.showPermissions()
            return
        }
        pasteManager.paste(text: lastTranscript, mode: settings.pasteMode)
        isPasteReady = false
        statusBarController.clearPasteReadyIndicator()
    }

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        pasteManager.copyToClipboard(text: lastTranscript)
    }

    func clearTranscript() {
        lastTranscript = ""
        lastAudioFileURL = nil
        isPasteReady = false
        statusBarController.clearPasteReadyIndicator()
    }

    private func describeTranscriptionError(_ error: Error) -> String {
        if let error = error as? TranscriptionError {
            switch error {
            case .missingWhisperBinary:
                return "Whisper binary not found"
            case .missingModel:
                return "Whisper model not found"
            case .conversionFailed:
                return "Audio conversion failed"
            case .processFailed:
                return "Whisper process failed"
            case .emptyResult:
                return "No transcript produced"
            }
        }
        return "Transcription failed"
    }
}

enum RecordingMode {
    case none
    case toggle
    case hold
}
