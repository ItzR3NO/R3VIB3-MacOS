import Foundation

struct WhisperTranscriptParser {
    static func parse(output: String) -> String {
        let lines = output.split(separator: "\n")
        let cleaned = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.hasPrefix("[") { return nil }
            if trimmed.hasPrefix("whisper_") { return nil }
            if trimmed.hasPrefix("main") { return nil }
            return trimmed
        }
        return cleaned.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
