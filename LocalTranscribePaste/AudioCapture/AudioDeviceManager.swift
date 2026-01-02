import Foundation
import CoreAudio
import AudioToolbox

struct AudioInputDevice: Identifiable, Hashable {
    let deviceID: AudioDeviceID
    let name: String
    let uid: String
    let channels: Int

    var id: String { uid }
}

enum AudioDeviceManager {
    static func inputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { return [] }
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        var results: [AudioInputDevice] = []
        results.reserveCapacity(deviceIDs.count)
        for deviceID in deviceIDs {
            let channels = inputChannelCount(deviceID: deviceID)
            if channels == 0 { continue }
            let name = deviceName(deviceID: deviceID) ?? "Unknown"
            let uid = deviceUID(deviceID: deviceID) ?? ""
            results.append(AudioInputDevice(deviceID: deviceID, name: name, uid: uid, channels: channels))
        }
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr else { return nil }
        return deviceID
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        let devices = inputDevices()
        return devices.first(where: { $0.uid == uid })?.deviceID
    }

    static func builtInMicrophoneDeviceID() -> AudioDeviceID? {
        let devices = inputDevices()
        for device in devices {
            if isBuiltIn(deviceID: device.deviceID) {
                return device.deviceID
            }
        }
        return nil
    }

    static func deviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var name: CFString = "" as CFString
        let status = withUnsafeMutableBytes(of: &name) { rawBuffer in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                rawBuffer.baseAddress!
            )
        }
        guard status == noErr else { return nil }
        return name as String
    }

    static func deviceUID(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var uid: CFString = "" as CFString
        let status = withUnsafeMutableBytes(of: &uid) { rawBuffer in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                rawBuffer.baseAddress!
            )
        }
        guard status == noErr else { return nil }
        return uid as String
    }

    static func inputChannelCount(deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { return 0 }
        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }
        let bufferList = bufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            bufferList
        )
        guard status == noErr else { return 0 }
        return withUnsafePointer(to: &bufferList.pointee.mBuffers) { mBuffersPtr in
            let buffers = UnsafeBufferPointer(start: mBuffersPtr, count: Int(bufferList.pointee.mNumberBuffers))
            return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        }
    }

    static func isBuiltIn(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &transportType
        )
        guard status == noErr else { return false }
        return transportType == kAudioDeviceTransportTypeBuiltIn
    }
}
