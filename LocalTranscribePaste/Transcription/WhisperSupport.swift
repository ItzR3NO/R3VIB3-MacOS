import Foundation

protocol WhisperLogging {
    func logExecutableMarkFailed(error: Error)
}

struct DefaultWhisperLogger: WhisperLogging {
    func logExecutableMarkFailed(error: Error) {
        Log.transcription.error("Failed to mark whisper-cli executable: \(error.localizedDescription)")
    }
}
