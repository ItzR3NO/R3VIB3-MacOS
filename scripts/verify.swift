import Foundation
import Carbon

@main
struct VerifyMain {
    static func main() {
        func assertEqual(_ actual: String, _ expected: String, _ message: String) {
            if actual != expected {
                fatalError("Assertion failed: \(message)\nExpected: \(expected)\nActual: \(actual)")
            }
        }

        let output = """
        [00:00.00 --> 00:01.00] hello
        whisper_init: ok
        main: done
        Hi there
        """

        let parsed = WhisperTranscriptParser.parse(output: output)
        assertEqual(parsed, "Hi there", "WhisperTranscriptParser filters metadata lines")

        let fnHotkey = Hotkey(keyCode: 0, modifiers: 0, usesFunction: true, isFunctionOnly: true)
        assertEqual(fnHotkey.displayString(), "Fn", "Fn-only hotkey label")

        let hotkey = Hotkey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))
        assertEqual(hotkey.displayString(), "Ctrl+Opt+A", "Modifier order for hotkey display")

        print("verify.swift: OK")
    }
}
