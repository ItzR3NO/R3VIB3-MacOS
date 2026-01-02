import Foundation
import AVFoundation

final class TranscriptionManager {
    private let engine: TranscriptionEngine
    private let queue = DispatchQueue(label: "transcription.queue", qos: .userInitiated)

    init(engine: TranscriptionEngine = WhisperCLITranscriber()) {
        self.engine = engine
    }

    func transcribe(audioURL: URL, modelPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let resampledURL = try self.convertTo16kMonoPCM(inputURL: audioURL)
                self.engine.transcribe(audioURL: resampledURL, modelPath: modelPath, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func convertTo16kMonoPCM(inputURL: URL) throws -> URL {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let inputFormat = inputFile.processingFormat
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)

        guard let format = outputFormat else { throw TranscriptionError.conversionFailed }
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else { throw TranscriptionError.conversionFailed }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ltp_resampled_\(UUID().uuidString).wav")

        let inputFrameCount = AVAudioFrameCount(inputFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputFrameCount) else {
            throw TranscriptionError.conversionFailed
        }
        try inputFile.read(into: inputBuffer)
        Log.transcription.info("Input audio: sr=\(inputFormat.sampleRate, privacy: .public) ch=\(inputFormat.channelCount, privacy: .public) frames=\(inputBuffer.frameLength, privacy: .public)")

        let monoBuffer = try extractMonoBuffer(from: inputBuffer, format: inputFormat)

        let outputFrameCapacity = AVAudioFrameCount(Double(monoBuffer.frameLength) * 16000.0 / inputFormat.sampleRate) + 1
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity) else {
            throw TranscriptionError.conversionFailed
        }

        var didProvideInput = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return monoBuffer
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if let error = error { throw error }
        if outputBuffer.frameLength > 0 {
            let peak = peakAmplitude(buffer: outputBuffer)
            Log.transcription.info("Resampled audio: frames=\(outputBuffer.frameLength, privacy: .public) peak=\(peak, privacy: .public)")
            try writeWav(url: outputURL, format: format, buffer: outputBuffer)
        } else {
            throw TranscriptionError.emptyResult
        }

        return outputURL
    }

    private func extractMonoBuffer(from inputBuffer: AVAudioPCMBuffer, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let channelCount = Int(format.channelCount)
        if channelCount <= 1 {
            return inputBuffer
        }

        if let floatData = inputBuffer.floatChannelData {
            let frameCount = Int(inputBuffer.frameLength)
            if frameCount == 0 { throw TranscriptionError.emptyResult }
            var peaks = [Float](repeating: 0, count: channelCount)
            for ch in 0..<channelCount {
                let samples = floatData[ch]
                var peak: Float = 0
                for i in 0..<frameCount {
                    let value = abs(samples[i])
                    if value > peak { peak = value }
                }
                peaks[ch] = peak
            }
            let maxChannel = peaks.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            Log.transcription.info("Channel peaks: \(peaks, privacy: .public) using=\(maxChannel, privacy: .public)")

            guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1) else {
                throw TranscriptionError.conversionFailed
            }
            guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: inputBuffer.frameCapacity) else {
                throw TranscriptionError.conversionFailed
            }
            monoBuffer.frameLength = inputBuffer.frameLength
            let dest = monoBuffer.floatChannelData![0]
            let src = floatData[maxChannel]
            dest.update(from: src, count: frameCount)
            return monoBuffer
        }

        if let int16Data = inputBuffer.int16ChannelData {
            let frameCount = Int(inputBuffer.frameLength)
            if frameCount == 0 { throw TranscriptionError.emptyResult }
            var peaks = [Float](repeating: 0, count: channelCount)
            for ch in 0..<channelCount {
                let samples = int16Data[ch]
                var peak: Int16 = 0
                for i in 0..<frameCount {
                    let value = samples[i]
                    let absValue = value == Int16.min ? Int16.max : abs(value)
                    if absValue > peak { peak = absValue }
                }
                peaks[ch] = Float(peak) / Float(Int16.max)
            }
            let maxChannel = peaks.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            Log.transcription.info("Channel peaks: \(peaks, privacy: .public) using=\(maxChannel, privacy: .public)")

            guard let monoFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: format.sampleRate, channels: 1, interleaved: true) else {
                throw TranscriptionError.conversionFailed
            }
            guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: inputBuffer.frameCapacity) else {
                throw TranscriptionError.conversionFailed
            }
            monoBuffer.frameLength = inputBuffer.frameLength
            let dest = monoBuffer.int16ChannelData![0]
            let src = int16Data[maxChannel]
            dest.update(from: src, count: frameCount)
            return monoBuffer
        }

        throw TranscriptionError.conversionFailed
    }

    private func peakAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        if let int16Data = buffer.int16ChannelData {
            let count = Int(buffer.frameLength)
            if count == 0 { return 0 }
            var peak: Int16 = 0
            let samples = int16Data[0]
            for i in 0..<count {
                let value = samples[i]
                let absValue = value == Int16.min ? Int16.max : abs(value)
                if absValue > peak { peak = absValue }
            }
            return Float(peak) / Float(Int16.max)
        }
        if let floatData = buffer.floatChannelData {
            let count = Int(buffer.frameLength)
            if count == 0 { return 0 }
            var peak: Float = 0
            let samples = floatData[0]
            for i in 0..<count {
                let value = abs(samples[i])
                if value > peak { peak = value }
            }
            return peak
        }
        return 0
    }

    private func writeWav(url: URL, format: AVAudioFormat, buffer: AVAudioPCMBuffer) throws {
        let channels = Int(format.channelCount)
        let sampleRate = Int(format.sampleRate)
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = Int(buffer.frameLength) * channels * bytesPerSample

        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.append(UInt32(36 + dataSize).littleEndianData)
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.append(UInt32(16).littleEndianData) // PCM chunk size
        header.append(UInt16(1).littleEndianData)  // PCM format
        header.append(UInt16(channels).littleEndianData)
        header.append(UInt32(sampleRate).littleEndianData)
        header.append(UInt32(sampleRate * channels * bytesPerSample).littleEndianData)
        header.append(UInt16(channels * bytesPerSample).littleEndianData)
        header.append(UInt16(bitsPerSample).littleEndianData)
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.append(UInt32(dataSize).littleEndianData)

        var data = Data()
        data.append(header)

        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        if let mData = audioBuffer.mData {
            data.append(Data(bytes: mData, count: dataSize))
        } else if let int16Data = buffer.int16ChannelData {
            data.append(Data(bytes: int16Data[0], count: dataSize))
        } else {
            throw TranscriptionError.conversionFailed
        }

        try data.write(to: url, options: .atomic)
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
