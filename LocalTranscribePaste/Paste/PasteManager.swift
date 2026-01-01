import Foundation
import AppKit
import Carbon

final class PasteManager {
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func paste(text: String, mode: PasteMode) {
        copyToClipboard(text: text)
        switch mode {
        case .cmdV:
            sendPaste(modifier: .maskCommand)
        case .ctrlV:
            sendPaste(modifier: .maskControl)
        case .type:
            typeString(text)
        }
        Log.paste.info("Paste action executed")
    }

    private func sendPaste(modifier: CGEventFlags) {
        let keyV = CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        keyDown?.flags = modifier
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        keyUp?.flags = modifier
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func typeString(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for char in text {
            if char == "\n" {
                sendKey(code: CGKeyCode(kVK_Return), shift: false, source: source)
                usleep(20000)
                continue
            }
            if let mapping = keyCodeForCharacter(char) {
                sendKey(code: mapping.code, shift: mapping.shift, source: source)
            } else {
                sendKey(code: CGKeyCode(kVK_ANSI_Slash), shift: true, source: source)
            }
            usleep(20000)
        }
    }

    private func sendKey(code: CGKeyCode, shift: Bool, source: CGEventSource?) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        if shift { keyDown?.flags = .maskShift }
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        if shift { keyUp?.flags = .maskShift }
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func keyCodeForCharacter(_ char: Character) -> (code: CGKeyCode, shift: Bool)? {
        let lower = String(char).lowercased()
        if lower.count != 1 { return nil }
        let scalar = lower.unicodeScalars.first!.value

        switch scalar {
        case 97...122:
            let code = CGKeyCode(kVK_ANSI_A + Int(scalar - 97))
            let shift = String(char) != lower
            return (code, shift)
        case 48...57:
            let code = CGKeyCode(kVK_ANSI_0 + Int(scalar - 48))
            return (code, false)
        default:
            break
        }

        let map: [Character: (CGKeyCode, Bool)] = [
            " ": (CGKeyCode(kVK_Space), false),
            ".": (CGKeyCode(kVK_ANSI_Period), false),
            ",": (CGKeyCode(kVK_ANSI_Comma), false),
            "?": (CGKeyCode(kVK_ANSI_Slash), true),
            "/": (CGKeyCode(kVK_ANSI_Slash), false),
            "-": (CGKeyCode(kVK_ANSI_Minus), false),
            "_": (CGKeyCode(kVK_ANSI_Minus), true),
            "=": (CGKeyCode(kVK_ANSI_Equal), false),
            "+": (CGKeyCode(kVK_ANSI_Equal), true),
            "'": (CGKeyCode(kVK_ANSI_Quote), false),
            "\"": (CGKeyCode(kVK_ANSI_Quote), true),
            ";": (CGKeyCode(kVK_ANSI_Semicolon), false),
            ":": (CGKeyCode(kVK_ANSI_Semicolon), true),
            "[": (CGKeyCode(kVK_ANSI_LeftBracket), false),
            "{": (CGKeyCode(kVK_ANSI_LeftBracket), true),
            "]": (CGKeyCode(kVK_ANSI_RightBracket), false),
            "}": (CGKeyCode(kVK_ANSI_RightBracket), true),
            "\\": (CGKeyCode(kVK_ANSI_Backslash), false),
            "|": (CGKeyCode(kVK_ANSI_Backslash), true),
            "`": (CGKeyCode(kVK_ANSI_Grave), false),
            "~": (CGKeyCode(kVK_ANSI_Grave), true),
            "!": (CGKeyCode(kVK_ANSI_1), true),
            "@": (CGKeyCode(kVK_ANSI_2), true),
            "#": (CGKeyCode(kVK_ANSI_3), true),
            "$": (CGKeyCode(kVK_ANSI_4), true),
            "%": (CGKeyCode(kVK_ANSI_5), true),
            "^": (CGKeyCode(kVK_ANSI_6), true),
            "&": (CGKeyCode(kVK_ANSI_7), true),
            "*": (CGKeyCode(kVK_ANSI_8), true),
            "(": (CGKeyCode(kVK_ANSI_9), true),
            ")": (CGKeyCode(kVK_ANSI_0), true)
        ]
        return map[char]
    }
}
