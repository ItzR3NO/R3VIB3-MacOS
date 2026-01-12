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
    private let microphoneAccess: MicrophoneAccessProviding
    private let accessibilityAccess: AccessibilityAccessProviding
    private let appActivator: AppActivating
    private let systemSettings: SystemSettingsOpening
    private let bundle: BundleProviding
    private let processRunner: ProcessRunning
    private let logger: PermissionsLogging
    private let mainThread: MainThreadRunning

    init(
        microphoneAccess: MicrophoneAccessProviding = SystemMicrophoneAccess(),
        accessibilityAccess: AccessibilityAccessProviding = SystemAccessibilityAccess(),
        appActivator: AppActivating = SystemAppActivator(),
        systemSettings: SystemSettingsOpening = SystemSettingsOpener(),
        bundle: BundleProviding = MainBundleProvider(),
        processRunner: ProcessRunning = SystemProcessRunner(),
        logger: PermissionsLogging = DefaultPermissionsLogger(),
        mainThread: MainThreadRunning = MainThreadRunner()
    ) {
        self.microphoneAccess = microphoneAccess
        self.accessibilityAccess = accessibilityAccess
        self.appActivator = appActivator
        self.systemSettings = systemSettings
        self.bundle = bundle
        self.processRunner = processRunner
        self.logger = logger
        self.mainThread = mainThread
    }

    var isMicrophoneAuthorized: Bool {
        return microphoneStatus == .authorized
    }

    var microphoneStatus: MicrophoneAuthorizationStatus {
        microphoneAccess.authorizationStatus
    }

    var isAccessibilityAuthorized: Bool {
        accessibilityAccess.isTrusted
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        appActivator.activate()
        microphoneAccess.requestAccess { granted, source in
            self.logger.logMicrophoneAccess(granted: granted, source: source)
            self.mainThread.run {
                completion(granted)
            }
        }
    }

    func forceMicrophonePrompt(completion: @escaping (Bool) -> Void) {
        requestMicrophoneAccess(completion: completion)
    }

    func openMicrophoneSettings() {
        appActivator.activate()
        systemSettings.openMicrophonePrivacy()
    }

    func requestAccessibilityAccess() {
        let trusted = accessibilityAccess.requestAccessPrompt()
        logger.logAccessibilityPrompt(trusted: trusted)
    }

    func resetAccessibilityPermissionIfNeeded() {
        guard !isAccessibilityAuthorized else { return }
        guard let bundleID = bundle.bundleIdentifier else { return }
        let tccutil = URL(fileURLWithPath: "/usr/bin/tccutil")
        do {
            let result = try processRunner.run(executableURL: tccutil, arguments: ["reset", "Accessibility", bundleID])
            logger.logTCCReset(service: "Accessibility", bundleID: bundleID, status: result.terminationStatus)
        } catch {
            logger.logTCCResetFailed(service: "Accessibility", bundleID: bundleID, error: error)
        }
    }

    func logCurrentStatus() {
        let captureStatus = microphoneAccess.captureAuthorizationStatusDescription
        let audioStatus = microphoneAccess.recordPermissionDescription
        logger.logPermissionStatus(
            micAuthorized: isMicrophoneAuthorized,
            captureStatus: captureStatus,
            avfaudioStatus: audioStatus,
            accessibilityAuthorized: isAccessibilityAuthorized
        )
    }
}
