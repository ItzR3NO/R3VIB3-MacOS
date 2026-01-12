import Foundation
import CoreGraphics

protocol EventTapCreating {
    func makeTap(mask: CGEventMask, callback: @escaping CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> CFMachPort?
}

struct SystemEventTapFactory: EventTapCreating {
    func makeTap(mask: CGEventMask, callback: @escaping CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> CFMachPort? {
        CGEvent.tapCreate(tap: .cgSessionEventTap,
                          place: .headInsertEventTap,
                          options: .listenOnly,
                          eventsOfInterest: mask,
                          callback: callback,
                          userInfo: userInfo)
    }
}

protocol RunLoopScheduling {
    func createSource(for tap: CFMachPort) -> CFRunLoopSource
    func add(source: CFRunLoopSource)
    func remove(source: CFRunLoopSource)
    func enableTap(_ tap: CFMachPort)
}

struct CoreRunLoopScheduler: RunLoopScheduling {
    func createSource(for tap: CFMachPort) -> CFRunLoopSource {
        CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    }

    func add(source: CFRunLoopSource) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    }

    func remove(source: CFRunLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }

    func enableTap(_ tap: CFMachPort) {
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

protocol HotkeyLogging {
    func logAccessibilityPrompt()
    func logEventTapFailed()
    func logHoldHotkeyEnabled()
}

struct DefaultHotkeyLogger: HotkeyLogging {
    func logAccessibilityPrompt() {
        Log.hotkeys.warning("Accessibility not trusted; prompted user")
    }

    func logEventTapFailed() {
        Log.hotkeys.error("Failed to create event tap for hold hotkey")
    }

    func logHoldHotkeyEnabled() {
        Log.hotkeys.info("Hold hotkey monitoring enabled")
    }
}
