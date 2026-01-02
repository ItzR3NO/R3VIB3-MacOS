import Foundation
import AVFoundation

final class AudioCaptureManager {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false

    func startRecording(preferredDeviceUID: String?, preferredChannelIndex: Int) throws {
        guard !isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ltp_recording_\(UUID().uuidString).caf")
        recordingURL = tempURL

        do {
            try startRecorder(at: tempURL, sampleRate: 44100)
        } catch {
            Log.audio.error("Recorder start failed at 44.1k: \(String(describing: error), privacy: .public)")
            try startRecorder(at: tempURL, sampleRate: 48000)
        }

        isRecording = true
        Log.audio.info("Recording start (AVAudioRecorder). url=\(tempURL.path, privacy: .public)")
    }

    func stopRecording() throws -> URL {
        guard isRecording else { throw AudioCaptureError.notRecording }
        recorder?.stop()
        recorder = nil
        isRecording = false
        guard let url = recordingURL else {
            throw AudioCaptureError.missingRecording
        }
        recordingURL = nil
        do {
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            Log.audio.info("Recording stop: frames=\(file.length, privacy: .public) dur=\(duration, privacy: .public)s")
        } catch {
            Log.audio.error("Failed to read recording: \(error.localizedDescription)")
        }
        return url
    }
}

private extension AudioCaptureManager {
    func startRecorder(at url: URL, sampleRate: Double) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioCaptureError.recorderFailed
        }
        self.recorder = recorder
    }
}

enum AudioCaptureError: Error {
    case notRecording
    case missingRecording
    case recorderFailed
}
