import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ScreenshotItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let screenFrame: CGRect?
    let sessionID: String?

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol ScreenshotStoring {
    func load() -> [ScreenshotItem]
    func capture(windowID: CGWindowID, screenFrameOverride: CGRect?) -> ScreenshotItem?
    func delete(_ item: ScreenshotItem)
    func pruneIfNeeded(keepLast: Int)
}

final class ScreenshotStore: ScreenshotStoring {
    private let fileSystem: FileSystem
    private let uuidProvider: UUIDProviding
    private let processRunner: ProcessRunning
    private let maxItems: Int
    private let sessionID: String?

    init(
        fileSystem: FileSystem = SystemFileSystem(),
        uuidProvider: UUIDProviding = SystemUUIDProvider(),
        processRunner: ProcessRunning = SystemProcessRunner(),
        maxItems: Int = 10,
        sessionID: String? = nil
    ) {
        self.fileSystem = fileSystem
        self.uuidProvider = uuidProvider
        self.processRunner = processRunner
        self.maxItems = maxItems
        self.sessionID = sessionID
    }

    func load() -> [ScreenshotItem] {
        let directory = screenshotsDirectory()
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return items.compactMap { url in
            guard url.pathExtension.lowercased() == "png" else { return nil }
            let values = try? url.resourceValues(forKeys: [.creationDateKey])
            let createdAt = values?.creationDate ?? Date.distantPast
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent.components(separatedBy: "-").last ?? "") ?? UUID()
            let metadata = readMetadataFull(for: url)
            return ScreenshotItem(
                id: id,
                url: url,
                createdAt: createdAt,
                screenFrame: metadata?.screenFrame.cgRect,
                sessionID: metadata?.sessionID
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func capture(windowID: CGWindowID, screenFrameOverride: CGRect?) -> ScreenshotItem? {
        guard windowID != 0 else { return nil }
        let id = uuidProvider.makeUUID()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "screenshot-\(timestamp)-\(id.uuidString).png"
        let url = screenshotsDirectory().appendingPathComponent(filename)
        let windowBounds = windowBoundsForWindow(windowID)
        let screenFrame = screenFrameOverride ?? windowBounds.flatMap { screenFrameForWindowBounds($0) }

        let imageOptions: CGWindowImageOption = [.bestResolution]
        if let cgImage = captureImage(windowID: windowID, bounds: .null, imageOptions: imageOptions) {
            if let windowBounds, isCompositeCapture(image: cgImage, windowBounds: windowBounds) {
                Log.screenshots.error(
                    "Captured image size \(cgImage.width, privacy: .public)x\(cgImage.height, privacy: .public) looks larger than window bounds \(NSStringFromRect(windowBounds), privacy: .public)"
                )
            } else {
                guard writePNG(cgImage: cgImage, to: url) else { return nil }
                writeMetadata(for: url, screenFrame: screenFrame)
                pruneIfNeeded(keepLast: maxItems)
                let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                return ScreenshotItem(
                    id: id,
                    url: url,
                    createdAt: createdAt,
                    screenFrame: screenFrame,
                    sessionID: sessionID
                )
            }
        }

        return nil
    }

    func delete(_ item: ScreenshotItem) {
        try? fileSystem.removeItem(at: item.url)
        try? fileSystem.removeItem(at: metadataURL(for: item.url))
    }

    func pruneIfNeeded(keepLast: Int) {
        let items = load()
        guard items.count > keepLast else { return }
        let toDelete = items.suffix(from: keepLast)
        for item in toDelete {
            delete(item)
        }
    }

    private func screenshotsDirectory() -> URL {
        let appSupport = fileSystem.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("R3VIB3/Screenshots", isDirectory: true)
        if !fileSystem.fileExists(atPath: dir.path) {
            try? fileSystem.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func writePNG(cgImage: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination)
    }

    private struct ScreenshotMetadata: Codable {
        let screenFrame: ScreenshotRect
        let sessionID: String?
    }

    private struct ScreenshotRect: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        init(_ rect: CGRect) {
            x = Double(rect.origin.x)
            y = Double(rect.origin.y)
            width = Double(rect.size.width)
            height = Double(rect.size.height)
        }

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    private func metadataURL(for screenshotURL: URL) -> URL {
        screenshotURL.deletingPathExtension().appendingPathExtension("meta.json")
    }

    private func writeMetadata(for screenshotURL: URL, screenFrame: CGRect?) {
        guard let screenFrame else { return }
        let metadata = ScreenshotMetadata(screenFrame: ScreenshotRect(screenFrame), sessionID: sessionID)
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: metadataURL(for: screenshotURL), options: [.atomic])
    }

    private func readMetadataFull(for screenshotURL: URL) -> ScreenshotMetadata? {
        let url = metadataURL(for: screenshotURL)
        guard let data = try? Data(contentsOf: url),
              let metadata = try? JSONDecoder().decode(ScreenshotMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }

    private func readMetadata(for screenshotURL: URL) -> CGRect? {
        readMetadataFull(for: screenshotURL)?.screenFrame.cgRect
    }

    private func captureImage(windowID: CGWindowID, bounds: CGRect, imageOptions: CGWindowImageOption) -> CGImage? {
        if let image = createImageFromArray(windowID: windowID, bounds: bounds, imageOptions: imageOptions) {
            Log.screenshots.info(
                "Captured window id \(windowID, privacy: .public) using CGWindowListCreateImageFromArray size \(image.width, privacy: .public)x\(image.height, privacy: .public)"
            )
            return image
        }
        let listOptions: CGWindowListOption = [.optionIncludingWindow]
        if let image = CGWindowListCreateImage(bounds, listOptions, windowID, imageOptions) {
            Log.screenshots.info(
                "Captured window id \(windowID, privacy: .public) using CGWindowListCreateImage size \(image.width, privacy: .public)x\(image.height, privacy: .public)"
            )
            return image
        }
        return nil
    }

    private func createImageFromArray(windowID: CGWindowID, bounds: CGRect, imageOptions: CGWindowImageOption) -> CGImage? {
        guard let windowArray = makeWindowIDArray([windowID]) else { return nil }
        return CGImage(windowListFromArrayScreenBounds: bounds, windowArray: windowArray, imageOption: imageOptions)
    }

    private func makeWindowIDArray(_ ids: [CGWindowID]) -> CFArray? {
        guard !ids.isEmpty else { return nil }
        var numbers: [CFNumber] = []
        numbers.reserveCapacity(ids.count)
        for windowID in ids {
            var rawValue = Int32(bitPattern: windowID)
            guard let number = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &rawValue) else {
                return nil
            }
            numbers.append(number)
        }
        return numbers as CFArray
    }

    private func isCompositeCapture(image: CGImage, windowBounds: CGRect) -> Bool {
        guard let expectedPixelSize = expectedPixelSize(for: windowBounds) else { return false }
        let widthRatio = CGFloat(image.width) / max(expectedPixelSize.width, 1)
        let heightRatio = CGFloat(image.height) / max(expectedPixelSize.height, 1)
        return widthRatio > 1.5 || heightRatio > 1.5
    }

    private func expectedPixelSize(for windowBounds: CGRect) -> CGSize? {
        guard let screen = screenForWindowBounds(windowBounds) else { return nil }
        let scale = screen.backingScaleFactor
        return CGSize(width: windowBounds.width * scale, height: windowBounds.height * scale)
    }

    private func screenFrameForWindowBounds(_ windowBounds: CGRect) -> CGRect? {
        screenForWindowBounds(windowBounds)?.frame
    }

    private func screenForWindowBounds(_ windowBounds: CGRect) -> NSScreen? {
        let appKitBounds = appKitBounds(for: windowBounds)
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let intersection = appKitBounds.intersection(screen.frame)
            let area = max(intersection.width, 0) * max(intersection.height, 0)
            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }
        if bestArea > 0 {
            return bestScreen
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(appKitBounds) })
    }

    private func appKitBounds(for cgBounds: CGRect) -> CGRect {
        let primaryHeight = primaryScreenHeight()
        return CGRect(
            x: cgBounds.origin.x,
            y: primaryHeight - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )
    }

    private func primaryScreenHeight() -> CGFloat {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary.frame.height
        }
        if let main = NSScreen.main {
            return main.frame.height
        }
        return 0
    }

    private func windowBoundsForWindow(_ windowID: CGWindowID) -> CGRect? {
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let infoList = CGWindowListCopyWindowInfo(options, windowID) as? [[String: Any]] else {
            return nil
        }
        for info in infoList {
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            if bounds.isNull || bounds.isEmpty { continue }
            return bounds
        }
        return nil
    }

}
