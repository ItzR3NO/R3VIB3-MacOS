import Foundation
import AVFoundation
import AVFAudio
import ApplicationServices
import AppKit

enum MicrophoneAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
}

final class PermissionsManager {
    var isMicrophoneAuthorized: Bool {
        return microphoneStatus == .authorized
    }

    var microphoneStatus: MicrophoneAuthorizationStatus {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .restricted
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                Log.permissions.info("Microphone permission granted (AVAudioApplication): \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Log.permissions.info("Microphone permission granted (AVCaptureDevice): \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func forceMicrophonePrompt(completion: @escaping (Bool) -> Void) {
        requestMicrophoneAccess(completion: completion)
    }

    func openMicrophoneSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let appURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
                return
            }
            let fallback = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(fallback)
        }
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.permissions.info("Accessibility permission prompt shown, trusted: \(trusted)")
    }

    func logCurrentStatus() {
        let captureStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        var audioStatus: String = "n/a"
        if #available(macOS 14.0, *) {
            audioStatus = String(describing: AVAudioApplication.shared.recordPermission)
        }
        Log.permissions.info("Permission status - mic:\(self.isMicrophoneAuthorized) capture:\(String(describing: captureStatus)) avfaudio:\(audioStatus) accessibility:\(self.isAccessibilityAuthorized)")
    }
}
