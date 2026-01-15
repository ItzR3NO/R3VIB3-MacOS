import os

enum Log {
    static let audio = Logger(subsystem: "com.localtranscribepaste.app", category: "audio")
    static let transcription = Logger(subsystem: "com.localtranscribepaste.app", category: "transcription")
    static let hotkeys = Logger(subsystem: "com.localtranscribepaste.app", category: "hotkeys")
    static let paste = Logger(subsystem: "com.localtranscribepaste.app", category: "paste")
    static let permissions = Logger(subsystem: "com.localtranscribepaste.app", category: "permissions")
    static let screenshots = Logger(subsystem: "com.localtranscribepaste.app", category: "screenshots")
}
