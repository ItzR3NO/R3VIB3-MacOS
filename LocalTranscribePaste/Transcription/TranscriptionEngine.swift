import Foundation

protocol TranscriptionEngine {
    func transcribe(audioURL: URL, modelPath: String, completion: @escaping (Result<String, Error>) -> Void)
}

enum TranscriptionError: Error {
    case missingWhisperBinary
    case missingModel
    case conversionFailed
    case processFailed(String)
    case emptyResult
}
