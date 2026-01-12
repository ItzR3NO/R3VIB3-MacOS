import Foundation
import AppKit
import Carbon

final class PasteManager {
    private let pasteboard: PasteboardWriting
    private let eventSender: KeyboardEventSending
    private let sleeper: SleepProviding
    private let logger: PasteLogging
    private let mainThread: MainThreadRunning

    init(
        pasteboard: PasteboardWriting = SystemPasteboard(),
        eventSender: KeyboardEventSending = SystemKeyboardEventSender(),
        sleeper: SleepProviding = SystemSleeper(),
        logger: PasteLogging = DefaultPasteLogger(),
        mainThread: MainThreadRunning = MainThreadRunner()
    ) {
        self.pasteboard = pasteboard
        self.eventSender = eventSender
        self.sleeper = sleeper
        self.logger = logger
        self.mainThread = mainThread
    }

    func copyToClipboard(text: String) {
        pasteboard.copy(text: text)
    }

    func paste(text: String, mode: PasteMode) {
        let snapshot = pasteboard.snapshot()
        let preChangeCount = pasteboard.changeCount
        copyToClipboard(text: text)
        switch mode {
        case .cmdV:
            eventSender.sendPaste(modifier: .maskCommand)
        case .ctrlV:
            eventSender.sendPaste(modifier: .maskControl)
        case .type:
            typeString(text)
        }
        restoreClipboardIfNeeded(snapshot: snapshot, preChangeCount: preChangeCount)
        logger.logPasteExecuted()
    }

    private func restoreClipboardIfNeeded(snapshot: PasteboardSnapshot, preChangeCount: Int) {
        mainThread.runAfter(seconds: 0.25) { [pasteboard, preChangeCount, snapshot] in
            if pasteboard.changeCount != preChangeCount + 1 { return }
            pasteboard.restore(snapshot)
        }
    }

    private func typeString(_ text: String) {
        for char in text {
            if char == "\n" {
                eventSender.sendKey(code: CGKeyCode(kVK_Return), shift: false)
                sleeper.sleep(microseconds: 20000)
                continue
            }
            if let mapping = keyCodeForCharacter(char) {
                eventSender.sendKey(code: mapping.code, shift: mapping.shift)
            } else {
                eventSender.sendKey(code: CGKeyCode(kVK_ANSI_Slash), shift: true)
            }
            sleeper.sleep(microseconds: 20000)
        }
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
