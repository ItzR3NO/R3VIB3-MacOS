import Foundation
import CoreGraphics
import Carbon

final class HoldHotkeyManager {
    static let shared = HoldHotkeyManager()

    var onToggle: (() -> Void)?
    var onPaste: (() -> Void)?
    var onHoldStart: (() -> Void)?
    var onHoldEnd: (() -> Void)?
    var onScreenshot: (() -> Void)?
    var onPasteKeystroke: ((UInt32, CGEventFlags) -> Void)?

    private let accessibilityAccess: AccessibilityAccessProviding
    private let eventTapFactory: EventTapCreating
    private let runLoop: RunLoopScheduling
    private let logger: HotkeyLogging
    private let mainThread: MainThreadRunning

    private var toggleHotkey: Hotkey = .defaultToggle
    private var pasteHotkey: Hotkey = .defaultPaste
    private var holdHotkey: Hotkey = .defaultHold
    private var screenshotHotkey: Hotkey = .defaultScreenshot
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed: Set<HotkeyKind> = []
    private var fnOnlyActive = false
    private var fnOnlyWorkItem: DispatchWorkItem?
    private var lastFlags: CGEventFlags = []

    init(
        accessibilityAccess: AccessibilityAccessProviding = SystemAccessibilityAccess(),
        eventTapFactory: EventTapCreating = SystemEventTapFactory(),
        runLoop: RunLoopScheduling = CoreRunLoopScheduler(),
        logger: HotkeyLogging = DefaultHotkeyLogger(),
        mainThread: MainThreadRunning = MainThreadRunner()
    ) {
        self.accessibilityAccess = accessibilityAccess
        self.eventTapFactory = eventTapFactory
        self.runLoop = runLoop
        self.logger = logger
        self.mainThread = mainThread
    }

    func updateHotkeys(toggle: Hotkey, paste: Hotkey, hold: Hotkey, screenshot: Hotkey) {
        toggleHotkey = toggle
        pasteHotkey = paste
        holdHotkey = hold
        screenshotHotkey = screenshot
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

    func updateScreenshotHotkey(_ hotkey: Hotkey) {
        screenshotHotkey = hotkey
    }

    func start() {
        guard eventTap == nil else { return }
        if !accessibilityAccess.isTrusted {
            _ = accessibilityAccess.requestAccessPrompt()
            logger.logAccessibilityPrompt()
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
        guard let tap = eventTapFactory.makeTap(mask: CGEventMask(mask), callback: callback, userInfo: userInfo) else {
            logger.logEventTapFailed()
            return
        }
        eventTap = tap
        runLoopSource = runLoop.createSource(for: tap)
        if let runLoopSource = runLoopSource {
            runLoop.add(source: runLoopSource)
        }
        runLoop.enableTap(tap)
        logger.logHoldHotkeyEnabled()
    }

    func restartIfNeeded() {
        if eventTap != nil { return }
        start()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        if type == .flagsChanged {
            lastFlags = event.flags
            handleFunctionOnly(flags: event.flags)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown {
            cancelFnOnlyActions()
        }
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.union(lastFlags)
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

        if screenshotHotkey.requiresEventTap, matches(hotkey: screenshotHotkey, keyCode: keyCode, flags: flags) {
            if type == .keyDown {
                handle(kind: .screenshot, type: type) {
                    self.onScreenshot?()
                }
            } else {
                pressed.remove(.screenshot)
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
                scheduleFnOnlyActions()
            } else {
                cancelFnOnlyActions()
                if pressed.contains(.hold) {
                    handle(kind: .hold, type: .keyUp) { self.onHoldEnd?() }
                } else {
                    pressed.remove(.hold)
                }
            }
        }

        if toggleHotkey.isFunctionOnly, toggleHotkey.requiresEventTap {
            if eligible {
                scheduleFnOnlyActions()
            } else {
                cancelFnOnlyActions()
                pressed.remove(.toggle)
            }
        }

        if pasteHotkey.isFunctionOnly, pasteHotkey.requiresEventTap {
            if eligible {
                scheduleFnOnlyActions()
            } else {
                cancelFnOnlyActions()
                pressed.remove(.paste)
            }
        }

        if screenshotHotkey.isFunctionOnly, screenshotHotkey.requiresEventTap {
            if eligible {
                scheduleFnOnlyActions()
            } else {
                cancelFnOnlyActions()
                pressed.remove(.screenshot)
            }
        }
    }

    private func scheduleFnOnlyActions() {
        cancelFnOnlyActions()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.fnOnlyActive else { return }
            if self.holdHotkey.isFunctionOnly {
                self.handle(kind: .hold, type: .keyDown) { self.onHoldStart?() }
            }
            if self.toggleHotkey.isFunctionOnly, self.toggleHotkey.requiresEventTap {
                self.handle(kind: .toggle, type: .keyDown) { self.onToggle?() }
            }
            if self.pasteHotkey.isFunctionOnly, self.pasteHotkey.requiresEventTap {
                self.handle(kind: .paste, type: .keyDown) { self.onPaste?() }
            }
            if self.screenshotHotkey.isFunctionOnly, self.screenshotHotkey.requiresEventTap {
                self.handle(kind: .screenshot, type: .keyDown) { self.onScreenshot?() }
            }
        }
        fnOnlyWorkItem = workItem
        mainThread.runAfter(seconds: 0.2) {
            if workItem.isCancelled { return }
            workItem.perform()
        }
    }

    private func cancelFnOnlyActions() {
        fnOnlyWorkItem?.cancel()
        fnOnlyWorkItem = nil
    }

    private func handle(kind: HotkeyKind, type: CGEventType, action: @escaping () -> Void) {
        switch type {
        case .keyDown:
            guard !pressed.contains(kind) else { return }
            pressed.insert(kind)
            mainThread.run { action() }
        case .keyUp:
            pressed.remove(kind)
            mainThread.run { action() }
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
    case screenshot
}
