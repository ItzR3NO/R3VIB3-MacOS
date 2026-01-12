import Foundation
import AVFoundation

final class TranscriptionManager {
    private let engine: TranscriptionEngine
    private let converter: AudioConverting
    private let queue: DispatchQueue

    init(
        engine: TranscriptionEngine = WhisperCLITranscriber(),
        converter: AudioConverting = AVAudioConverterService(),
        queue: DispatchQueue = DispatchQueue(label: "transcription.queue", qos: .userInitiated)
    ) {
        self.engine = engine
        self.converter = converter
        self.queue = queue
    }

    func transcribe(audioURL: URL, modelPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let resampledURL = try self.converter.convertTo16kMonoPCM(inputURL: audioURL)
                self.engine.transcribe(audioURL: resampledURL, modelPath: modelPath, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }
}
