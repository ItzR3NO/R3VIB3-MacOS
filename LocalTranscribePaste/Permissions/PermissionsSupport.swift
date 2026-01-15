import Foundation
import AVFoundation
import AVFAudio
import ApplicationServices
import AppKit

protocol MicrophoneAccessProviding {
    var authorizationStatus: MicrophoneAuthorizationStatus { get }
    var captureAuthorizationStatusDescription: String { get }
    var recordPermissionDescription: String { get }
    func requestAccess(completion: @escaping (Bool, String) -> Void)
}

struct SystemMicrophoneAccess: MicrophoneAccessProviding {
    var authorizationStatus: MicrophoneAuthorizationStatus {
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

    var captureAuthorizationStatusDescription: String {
        String(describing: AVCaptureDevice.authorizationStatus(for: .audio))
    }

    var recordPermissionDescription: String {
        if #available(macOS 14.0, *) {
            return String(describing: AVAudioApplication.shared.recordPermission)
        }
        return "n/a"
    }

    func requestAccess(completion: @escaping (Bool, String) -> Void) {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted, "AVAudioApplication")
            }
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted, "AVCaptureDevice")
        }
    }
}

protocol AccessibilityAccessProviding {
    var isTrusted: Bool { get }
    func requestAccessPrompt() -> Bool
}

struct SystemAccessibilityAccess: AccessibilityAccessProviding {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

protocol ScreenRecordingAccessProviding {
    var isAuthorized: Bool { get }
    func requestAccess() -> Bool
}

struct SystemScreenRecordingAccess: ScreenRecordingAccessProviding {
    var isAuthorized: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

protocol AppActivating {
    func activate()
}

struct SystemAppActivator: AppActivating {
    func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

protocol SystemSettingsOpening {
    func openMicrophonePrivacy()
    func openScreenRecordingPrivacy()
}

struct SystemSettingsOpener: SystemSettingsOpening {
    func openMicrophonePrivacy() {
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

    func openScreenRecordingPrivacy() {
        let appURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
                return
            }
            let fallback = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(fallback)
        }
    }
}

protocol PermissionsLogging {
    func logMicrophoneAccess(granted: Bool, source: String)
    func logAccessibilityPrompt(trusted: Bool)
    func logScreenRecordingAccess(granted: Bool)
    func logTCCReset(service: String, bundleID: String, status: Int32)
    func logTCCResetFailed(service: String, bundleID: String, error: Error)
    func logPermissionStatus(micAuthorized: Bool, captureStatus: String, avfaudioStatus: String, accessibilityAuthorized: Bool, screenRecordingAuthorized: Bool)
}

struct DefaultPermissionsLogger: PermissionsLogging {
    func logMicrophoneAccess(granted: Bool, source: String) {
        Log.permissions.info("Microphone permission granted (\(source, privacy: .public)): \(granted)")
    }

    func logAccessibilityPrompt(trusted: Bool) {
        Log.permissions.info("Accessibility permission prompt shown, trusted: \(trusted)")
    }

    func logScreenRecordingAccess(granted: Bool) {
        Log.permissions.info("Screen recording permission granted: \(granted)")
    }

    func logTCCReset(service: String, bundleID: String, status: Int32) {
        Log.permissions.info("TCC reset \(service, privacy: .public) for \(bundleID, privacy: .public) status: \(status)")
    }

    func logTCCResetFailed(service: String, bundleID: String, error: Error) {
        Log.permissions.error("TCC reset failed \(service, privacy: .public) for \(bundleID, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    func logPermissionStatus(micAuthorized: Bool, captureStatus: String, avfaudioStatus: String, accessibilityAuthorized: Bool, screenRecordingAuthorized: Bool) {
        Log.permissions.info("Permission status - mic:\(micAuthorized) capture:\(captureStatus, privacy: .public) avfaudio:\(avfaudioStatus, privacy: .public) accessibility:\(accessibilityAuthorized) screen:\(screenRecordingAuthorized)")
    }
}
