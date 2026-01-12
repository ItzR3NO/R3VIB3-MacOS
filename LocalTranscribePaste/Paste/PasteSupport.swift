import AppKit
import Carbon
import Foundation

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

protocol PasteboardWriting {
    var changeCount: Int { get }
    func copy(text: String)
    func snapshot() -> PasteboardSnapshot
    func restore(_ snapshot: PasteboardSnapshot)
}

struct SystemPasteboard: PasteboardWriting {
    var changeCount: Int {
        NSPasteboard.general.changeCount
    }

    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func snapshot() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        let items: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        let restoredItems = snapshot.items.map { itemData -> NSPasteboardItem in
            let newItem = NSPasteboardItem()
            for (type, data) in itemData {
                newItem.setData(data, forType: type)
            }
            return newItem
        }
        _ = pasteboard.writeObjects(restoredItems)
    }
}

protocol KeyboardEventSending {
    func sendPaste(modifier: CGEventFlags)
    func sendKey(code: CGKeyCode, shift: Bool)
}

struct SystemKeyboardEventSender: KeyboardEventSending {
    func sendPaste(modifier: CGEventFlags) {
        let keyV = CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        keyDown?.flags = modifier
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        keyUp?.flags = modifier
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func sendKey(code: CGKeyCode, shift: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        if shift { keyDown?.flags = .maskShift }
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        if shift { keyUp?.flags = .maskShift }
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

protocol PasteLogging {
    func logPasteExecuted()
}

struct DefaultPasteLogger: PasteLogging {
    func logPasteExecuted() {
        Log.paste.info("Paste action executed")
    }
}
