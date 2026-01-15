import Foundation
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onToggleDictation: (() -> Void)?
    var onPasteLastTranscript: (() -> Void)?
    var onCaptureScreenshot: (() -> Void)?

    private let mainThread: MainThreadRunning
    private var toggleRef: EventHotKeyRef?
    private var pasteRef: EventHotKeyRef?
    private var screenshotRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init(mainThread: MainThreadRunning = MainThreadRunner()) {
        self.mainThread = mainThread
        installHandler()
    }

    func registerHotkeys(toggle: Hotkey?, paste: Hotkey?, screenshot: Hotkey?) {
        unregisterHotkeys()
        if let toggle = toggle {
            register(hotkey: toggle, id: HotkeyID.toggle, ref: &toggleRef)
        }
        if let paste = paste {
            register(hotkey: paste, id: HotkeyID.paste, ref: &pasteRef)
        }
        if let screenshot = screenshot {
            register(hotkey: screenshot, id: HotkeyID.screenshot, ref: &screenshotRef)
        }
        Log.hotkeys.info("Registered hotkeys")
    }

    private func register(hotkey: Hotkey, id: HotkeyID, ref: inout EventHotKeyRef?) {
        let hotkeyID = EventHotKeyID(signature: fourCharCode("LTPA"), id: id.rawValue)
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.carbonFlags, hotkeyID, GetEventDispatcherTarget(), 0, &ref)
        if status != noErr {
            Log.hotkeys.error("Failed to register hotkey \(id.rawValue)")
        }
    }

    private func unregisterHotkeys() {
        if let toggleRef { UnregisterEventHotKey(toggleRef) }
        if let pasteRef { UnregisterEventHotKey(pasteRef) }
        if let screenshotRef { UnregisterEventHotKey(screenshotRef) }
        toggleRef = nil
        pasteRef = nil
        screenshotRef = nil
    }

    private func installHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, eventRef, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotkeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            manager.mainThread.run {
                switch HotkeyID(rawValue: hotkeyID.id) {
                case .toggle:
                    manager.onToggleDictation?()
                case .paste:
                    manager.onPasteLastTranscript?()
                case .screenshot:
                    manager.onCaptureScreenshot?()
                case .none:
                    break
                }
            }
            return noErr
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, userInfo, &eventHandler)
    }
}

private enum HotkeyID: UInt32 {
    case toggle = 1
    case paste = 2
    case screenshot = 3
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for scalar in string.unicodeScalars {
        result = (result << 8) + FourCharCode(scalar.value)
    }
    return result
}
