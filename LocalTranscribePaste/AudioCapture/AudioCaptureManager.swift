import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio

final class AudioCaptureManager {
    private let engine = AVAudioEngine()
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var isRecording = false
    private var inputFormat: AVAudioFormat?
    private var isConfigured = false
    private var activeDeviceID: AudioDeviceID?
    private var preferredChannelIndex: Int = 0
    private var activeChannelIndex: Int?

    func startRecording(preferredDeviceUID: String?, preferredChannelIndex: Int) throws {
        guard !isRecording else { return }
        self.preferredChannelIndex = preferredChannelIndex
        activeChannelIndex = nil
        selectInputDevice(preferredUID: preferredDeviceUID)
        configureEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        self.inputFormat = inputFormat
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: 1) else {
            throw AudioCaptureError.invalidFormat
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ltp_recording_\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: tempURL, settings: monoFormat.settings)
        recordingFile = file
        recordingURL = tempURL
        Log.audio.info("Recording start: sr=\(inputFormat.sampleRate, privacy: .public) inCh=\(inputFormat.channelCount, privacy: .public) tapCh=\(monoFormat.channelCount, privacy: .public) url=\(tempURL.path, privacy: .public)")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            do {
                if inputFormat.channelCount <= 1 {
                    try self.recordingFile?.write(from: buffer)
                    return
                }

                guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameCapacity) else {
                    throw AudioCaptureError.invalidFormat
                }
                monoBuffer.frameLength = buffer.frameLength

                let channelIndex = self.resolveChannelIndex(buffer: buffer)
                if let floatData = buffer.floatChannelData, let dest = monoBuffer.floatChannelData?[0] {
                    let src = floatData[channelIndex]
                    dest.update(from: src, count: Int(buffer.frameLength))
                } else if let int16Data = buffer.int16ChannelData, let dest = monoBuffer.int16ChannelData?[0] {
                    let src = int16Data[channelIndex]
                    dest.update(from: src, count: Int(buffer.frameLength))
                } else {
                    throw AudioCaptureError.invalidFormat
                }

                try self.recordingFile?.write(from: monoBuffer)
            } catch {
                Log.audio.error("Failed to write buffer: \(error.localizedDescription)")
            }
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopRecording() throws -> URL {
        guard isRecording else { throw AudioCaptureError.notRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRecording = false
        guard let url = recordingURL else {
            throw AudioCaptureError.missingRecording
        }
        // Close file to flush data before downstream reads.
        recordingFile = nil
        recordingURL = nil
        inputFormat = nil
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
    func configureEngine() {
        guard !isConfigured else { return }
        engine.reset()
        engine.mainMixerNode.outputVolume = 0
        isConfigured = true
    }

    func selectInputDevice(preferredUID: String?) {
        let defaultID = AudioDeviceManager.defaultInputDeviceID()
        var chosenID: AudioDeviceID? = defaultID

        if let preferredUID = preferredUID, !preferredUID.isEmpty, preferredUID != "system" {
            chosenID = AudioDeviceManager.deviceID(forUID: preferredUID) ?? defaultID
        } else if let defaultID = defaultID {
            let channels = AudioDeviceManager.inputChannelCount(deviceID: defaultID)
            if channels > 2, let builtIn = AudioDeviceManager.builtInMicrophoneDeviceID() {
                chosenID = builtIn
            }
        }

        guard let deviceID = chosenID else {
            Log.audio.error("Unable to resolve input device")
            return
        }

        if deviceID != activeDeviceID {
            setInputDevice(deviceID: deviceID)
            activeDeviceID = deviceID
            isConfigured = false
        }
    }

    func setInputDevice(deviceID: AudioDeviceID) {
        guard let audioUnit = engine.inputNode.audioUnit else {
            Log.audio.error("Missing audio unit for input node")
            return
        }
        var device = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status == noErr {
            let name = AudioDeviceManager.deviceName(deviceID: deviceID) ?? "Unknown"
            let channels = AudioDeviceManager.inputChannelCount(deviceID: deviceID)
            Log.audio.info("Using input device: \(name, privacy: .public) id=\(deviceID, privacy: .public) ch=\(channels, privacy: .public)")
        } else {
            Log.audio.error("Failed to set input device: \(status)")
        }
    }

    func resolveChannelIndex(buffer: AVAudioPCMBuffer) -> Int {
        let channels = Int(buffer.format.channelCount)
        if channels <= 1 { return 0 }
        if let activeChannelIndex = activeChannelIndex, activeChannelIndex < channels {
            return activeChannelIndex
        }
        let preferred = preferredChannelIndex
        if preferred > 0 {
            let idx = min(preferred - 1, channels - 1)
            activeChannelIndex = idx
            Log.audio.info("Using input channel \(idx + 1, privacy: .public) of \(channels, privacy: .public)")
            return idx
        }
        // Auto: pick loudest channel from first buffer
        var peaks = [Float](repeating: 0, count: channels)
        if let floatData = buffer.floatChannelData {
            let frameCount = Int(buffer.frameLength)
            for ch in 0..<channels {
                let samples = floatData[ch]
                var peak: Float = 0
                for i in 0..<frameCount {
                    let value = abs(samples[i])
                    if value > peak { peak = value }
                }
                peaks[ch] = peak
            }
        } else if let int16Data = buffer.int16ChannelData {
            let frameCount = Int(buffer.frameLength)
            for ch in 0..<channels {
                let samples = int16Data[ch]
                var peak: Int16 = 0
                for i in 0..<frameCount {
                    let value = samples[i]
                    let absValue = value == Int16.min ? Int16.max : abs(value)
                    if absValue > peak { peak = absValue }
                }
                peaks[ch] = Float(peak) / Float(Int16.max)
            }
        }
        let maxIndex = peaks.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        activeChannelIndex = maxIndex
        Log.audio.info("Auto channel peaks: \(peaks, privacy: .public) using=\(maxIndex + 1, privacy: .public)")
        return maxIndex
    }
}

enum AudioCaptureError: Error {
    case notRecording
    case missingRecording
    case invalidFormat
}
