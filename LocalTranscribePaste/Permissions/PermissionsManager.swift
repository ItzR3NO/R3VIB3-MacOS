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
        if #available(macOS 14.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
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

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.permissions.info("Accessibility permission prompt shown, trusted: \(trusted)")
    }

    func logCurrentStatus() {
        Log.permissions.info("Permission status - mic: \(self.isMicrophoneAuthorized), accessibility: \(self.isAccessibilityAuthorized)")
    }
}
