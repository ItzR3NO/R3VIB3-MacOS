import Foundation
import Carbon

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var usesFunction: Bool = false
    var isFunctionOnly: Bool = false

    var carbonFlags: UInt32 { modifiers }

    func displayString() -> String {
        if isFunctionOnly {
            return "Fn"
        }
        var parts: [String] = []
        if usesFunction { parts.append("Fn") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("Ctrl") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Opt") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        parts.append(keyCodeDisplay(keyCode))
        return parts.joined(separator: "+")
    }

    static let defaultToggle = Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
    static let defaultPaste = Hotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))
    static let defaultHold = Hotkey(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey))
    static let defaultScreenshot = Hotkey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey))

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
        case usesFunction
        case isFunctionOnly
    }

    init(keyCode: UInt32, modifiers: UInt32, usesFunction: Bool = false, isFunctionOnly: Bool = false) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.usesFunction = usesFunction
        self.isFunctionOnly = isFunctionOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        modifiers = try container.decode(UInt32.self, forKey: .modifiers)
        usesFunction = (try? container.decode(Bool.self, forKey: .usesFunction)) ?? false
        isFunctionOnly = (try? container.decode(Bool.self, forKey: .isFunctionOnly)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(usesFunction, forKey: .usesFunction)
        try container.encode(isFunctionOnly, forKey: .isFunctionOnly)
    }
}

extension Hotkey {
    var requiresEventTap: Bool {
        return usesFunction || isFunctionOnly
    }
}

private func keyCodeDisplay(_ keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Escape): "Esc"
    ]
    return map[keyCode] ?? "Key\(keyCode)"
}
