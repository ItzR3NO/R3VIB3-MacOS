import Foundation
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onToggleDictation: (() -> Void)?
    var onPasteLastTranscript: (() -> Void)?

    private var toggleRef: EventHotKeyRef?
    private var pasteRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {
        installHandler()
    }

    func registerHotkeys(toggle: Hotkey?, paste: Hotkey?) {
        unregisterHotkeys()
        if let toggle = toggle {
            register(hotkey: toggle, id: HotkeyID.toggle, ref: &toggleRef)
        }
        if let paste = paste {
            register(hotkey: paste, id: HotkeyID.paste, ref: &pasteRef)
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
        toggleRef = nil
        pasteRef = nil
    }

    private func installHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, eventRef, _ in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            DispatchQueue.main.async {
                switch HotkeyID(rawValue: hotkeyID.id) {
                case .toggle:
                    HotkeyManager.shared.onToggleDictation?()
                case .paste:
                    HotkeyManager.shared.onPasteLastTranscript?()
                case .none:
                    break
                }
            }
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, nil, &eventHandler)
    }
}

private enum HotkeyID: UInt32 {
    case toggle = 1
    case paste = 2
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for scalar in string.unicodeScalars {
        result = (result << 8) + FourCharCode(scalar.value)
    }
    return result
}
