import Foundation
import AVFoundation
import ApplicationServices

final class PermissionsManager {
    var isMicrophoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Log.permissions.info("Microphone permission granted: \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
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
