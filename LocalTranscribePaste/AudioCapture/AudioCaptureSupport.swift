import Foundation
import AVFoundation

protocol AudioRecorderFactory {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> AVAudioRecorder
}

struct AVAudioRecorderFactory: AudioRecorderFactory {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> AVAudioRecorder {
        try AVAudioRecorder(url: url, settings: settings)
    }
}

struct AudioFileInfo {
    let frameLength: AVAudioFramePosition
    let sampleRate: Double

    var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(frameLength) / sampleRate
    }
}

protocol AudioFileReading {
    func readInfo(url: URL) throws -> AudioFileInfo
}

struct SystemAudioFileReader: AudioFileReading {
    func readInfo(url: URL) throws -> AudioFileInfo {
        let file = try AVAudioFile(forReading: url)
        return AudioFileInfo(frameLength: file.length, sampleRate: file.processingFormat.sampleRate)
    }
}

protocol AudioCaptureLogging {
    func logRecorderStartFailed(sampleRate: Double, error: Error)
    func logRecordingStart(url: URL)
    func logRecordingStop(frameLength: AVAudioFramePosition, duration: Double)
    func logRecordingReadFailed(error: Error)
}

struct DefaultAudioCaptureLogger: AudioCaptureLogging {
    func logRecorderStartFailed(sampleRate: Double, error: Error) {
        let kilo = sampleRate / 1000.0
        Log.audio.error("Recorder start failed at \(kilo, privacy: .public)k: \(String(describing: error), privacy: .public)")
    }

    func logRecordingStart(url: URL) {
        Log.audio.info("Recording start (AVAudioRecorder). url=\(url.path, privacy: .public)")
    }

    func logRecordingStop(frameLength: AVAudioFramePosition, duration: Double) {
        Log.audio.info("Recording stop: frames=\(frameLength, privacy: .public) dur=\(duration, privacy: .public)s")
    }

    func logRecordingReadFailed(error: Error) {
        Log.audio.error("Failed to read recording: \(error.localizedDescription)")
    }
}
