import Foundation
import CoreGraphics
import Carbon

final class HoldHotkeyManager {
    static let shared = HoldHotkeyManager()

    var onToggle: (() -> Void)?
    var onPaste: (() -> Void)?
    var onHoldStart: (() -> Void)?
    var onHoldEnd: (() -> Void)?
    var onPasteKeystroke: ((UInt32, CGEventFlags) -> Void)?

    private var toggleHotkey: Hotkey = .defaultToggle
    private var pasteHotkey: Hotkey = .defaultPaste
    private var holdHotkey: Hotkey = .defaultHold
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed: Set<HotkeyKind> = []
    private var fnOnlyActive = false

    private init() {}

    func updateHotkeys(toggle: Hotkey, paste: Hotkey, hold: Hotkey) {
        toggleHotkey = toggle
        pasteHotkey = paste
        holdHotkey = hold
    }

    func updateHoldHotkey(_ hotkey: Hotkey) {
        holdHotkey = hotkey
    }

    func updateToggleHotkey(_ hotkey: Hotkey) {
        toggleHotkey = hotkey
    }

    func updatePasteHotkey(_ hotkey: Hotkey) {
        pasteHotkey = hotkey
    }

    func start() {
        guard eventTap == nil else { return }
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            Log.hotkeys.warning("Accessibility not trusted; prompted user")
            return
        }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HoldHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handleEvent(type: type, event: event)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .listenOnly,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: callback,
                                          userInfo: userInfo) else {
            Log.hotkeys.error("Failed to create event tap for hold hotkey")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkeys.info("Hold hotkey monitoring enabled")
    }

    func restartIfNeeded() {
        if eventTap != nil { return }
        start()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        if type == .flagsChanged {
            handleFunctionOnly(flags: event.flags)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        onPasteKeystroke?(keyCode, flags)

        if matches(hotkey: holdHotkey, keyCode: keyCode, flags: flags) {
            handle(kind: .hold, type: type) {
                if type == .keyDown {
                    self.onHoldStart?()
                } else {
                    self.onHoldEnd?()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        if toggleHotkey.requiresEventTap, matches(hotkey: toggleHotkey, keyCode: keyCode, flags: flags) {
            if type == .keyDown {
                handle(kind: .toggle, type: type) {
                    self.onToggle?()
                }
            } else {
                pressed.remove(.toggle)
            }
            return Unmanaged.passUnretained(event)
        }

        if pasteHotkey.requiresEventTap, matches(hotkey: pasteHotkey, keyCode: keyCode, flags: flags) {
            if type == .keyDown {
                handle(kind: .paste, type: type) {
                    self.onPaste?()
                }
            } else {
                pressed.remove(.paste)
            }
            return Unmanaged.passUnretained(event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func matches(hotkey: Hotkey, keyCode: UInt32, flags: CGEventFlags) -> Bool {
        if hotkey.isFunctionOnly {
            return false
        }
        guard keyCode == hotkey.keyCode else { return false }
        let mask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn]
        let expected = hotkey.cgFlags()
        return flags.intersection(mask) == expected.intersection(mask)
    }

    private func handleFunctionOnly(flags: CGEventFlags) {
        let fnPressed = flags.contains(.maskSecondaryFn)
        let otherModifiers = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let eligible = fnPressed && otherModifiers.isEmpty
        guard eligible != fnOnlyActive else { return }
        fnOnlyActive = eligible

        if holdHotkey.isFunctionOnly {
            if eligible {
                handle(kind: .hold, type: .keyDown) { self.onHoldStart?() }
            } else {
                handle(kind: .hold, type: .keyUp) { self.onHoldEnd?() }
            }
        }

        if toggleHotkey.isFunctionOnly, toggleHotkey.requiresEventTap {
            if eligible {
                handle(kind: .toggle, type: .keyDown) { self.onToggle?() }
            } else {
                pressed.remove(.toggle)
            }
        }

        if pasteHotkey.isFunctionOnly, pasteHotkey.requiresEventTap {
            if eligible {
                handle(kind: .paste, type: .keyDown) { self.onPaste?() }
            } else {
                pressed.remove(.paste)
            }
        }
    }

    private func handle(kind: HotkeyKind, type: CGEventType, action: @escaping () -> Void) {
        switch type {
        case .keyDown:
            guard !pressed.contains(kind) else { return }
            pressed.insert(kind)
            DispatchQueue.main.async { action() }
        case .keyUp:
            pressed.remove(kind)
            DispatchQueue.main.async { action() }
        default:
            break
        }
    }

}

private extension Hotkey {
    func cgFlags() -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        if usesFunction { flags.insert(.maskSecondaryFn) }
        return flags
    }
}

private enum HotkeyKind: Hashable {
    case toggle
    case paste
    case hold
}
