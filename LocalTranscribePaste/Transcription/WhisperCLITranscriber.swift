import Foundation

final class WhisperCLITranscriber: TranscriptionEngine {
    func transcribe(audioURL: URL, modelPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        let whisperURL = Bundle.main.url(forResource: "whisper-cli", withExtension: nil)
            ?? Bundle.main.url(forResource: "whisper-cli", withExtension: nil, subdirectory: "whisper")
        guard let whisperURL else {
            completion(.failure(TranscriptionError.missingWhisperBinary))
            return
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            completion(.failure(TranscriptionError.missingModel))
            return
        }
        ensureExecutable(url: whisperURL)

        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("ltp_out_\(UUID().uuidString)")
        let outputTextURL = outputBase.appendingPathExtension("txt")

        let process = Process()
        process.executableURL = whisperURL
        process.arguments = ["-m", modelPath, "-f", audioURL.path, "-otxt", "-of", outputBase.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            completion(.failure(error))
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let message = String(data: data, encoding: .utf8) ?? "whisper-cli failed"
            completion(.failure(TranscriptionError.processFailed(message)))
            return
        }

        if let outputText = try? String(contentsOf: outputTextURL), !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion(.success(outputText.trimmingCharacters(in: .whitespacesAndNewlines)))
            return
        }

        let stdout = String(data: data, encoding: .utf8) ?? ""
        let parsed = parseTranscript(from: stdout)
        if parsed.isEmpty {
            completion(.failure(TranscriptionError.emptyResult))
        } else {
            completion(.success(parsed))
        }
    }

    private func parseTranscript(from output: String) -> String {
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

    private func ensureExecutable(url: URL) {
        let path = url.path
        guard FileManager.default.isExecutableFile(atPath: path) == false else { return }
        do {
            var attributes = try FileManager.default.attributesOfItem(atPath: path)
            let current = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644
            let updated = NSNumber(value: current | 0o111)
            attributes[.posixPermissions] = updated
            try FileManager.default.setAttributes(attributes, ofItemAtPath: path)
        } catch {
            Log.transcription.error("Failed to mark whisper-cli executable: \(error.localizedDescription)")
        }
    }
}
