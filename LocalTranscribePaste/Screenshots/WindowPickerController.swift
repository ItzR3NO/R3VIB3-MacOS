import AppKit
import CoreGraphics

protocol WindowPicking {
    func beginSelection(completion: @escaping (WindowSelection?) -> Void)
    func cancel()
}

struct WindowSelection {
    let windowID: CGWindowID
    let screenFrame: CGRect?
}

final class WindowPickerController: WindowPicking {
    private var overlayWindow: WindowPickerOverlayWindow?
    private var completion: ((WindowSelection?) -> Void)?
    private var cachedWindows: [WindowInfo] = []
    private var isFinishing = false
    private var cancelWorkItem: DispatchWorkItem?

    func beginSelection(completion: @escaping (WindowSelection?) -> Void) {
        precondition(Thread.isMainThread)
        cancel()
        isFinishing = false
        self.completion = completion
        refreshWindowCache()
        let window = WindowPickerOverlayWindow(controller: self)
        overlayWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        let workItem = DispatchWorkItem { [weak self] in
            self?.cancel()
        }
        cancelWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    func cancel() {
        precondition(Thread.isMainThread)
        cancelWorkItem?.cancel()
        cancelWorkItem = nil
        completion = nil
        cachedWindows = []
        overlayWindow?.close()
        overlayWindow = nil
    }

    fileprivate func windowAtPoint(_ point: CGPoint) -> WindowInfo? {
        return cachedWindows.first { $0.appKitBounds.contains(point) }
    }

    fileprivate func selectWindow(_ window: WindowInfo?) {
        if let window {
            Log.screenshots.info(
                "Selected window id \(window.id, privacy: .public) owner \(window.ownerName, privacy: .public) title \(window.windowName, privacy: .public) cgBounds \(NSStringFromRect(window.cgBounds), privacy: .public) appKitBounds \(NSStringFromRect(window.appKitBounds), privacy: .public)"
            )
        } else {
            Log.screenshots.info("No window selected")
        }
        if let window {
            let screenFrame = screenFrameForAppKitBounds(window.appKitBounds)
            finishSelection(with: WindowSelection(windowID: window.id, screenFrame: screenFrame))
        } else {
            finishSelection(with: nil)
        }
    }

    private func refreshWindowCache() {
        autoreleasepool {
            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                cachedWindows = []
                return
            }
            var windows: [WindowInfo] = []
            windows.reserveCapacity(infoList.count)
            for info in infoList {
                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
                if bounds.isNull || bounds.isEmpty { continue }
                let layer = info[kCGWindowLayer as String] as? Int ?? 0
                if layer != 0 { continue }
                let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool ?? true
                if !isOnscreen { continue }
                let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
                if ownerName == "Window Server" { continue }
                let windowName = info[kCGWindowName as String] as? String ?? ""
                let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0
                if alpha == 0 { continue }
                let ownerPid = info[kCGWindowOwnerPID as String] as? Int ?? 0
                if ownerPid == Int(getpid()) { continue }
                guard let windowID = info[kCGWindowNumber as String] as? CGWindowID, windowID != 0 else { continue }
                let appKitBounds = appKitBounds(for: bounds)
                windows.append(WindowInfo(
                    id: windowID,
                    cgBounds: bounds.integral,
                    appKitBounds: appKitBounds.integral,
                    ownerName: ownerName,
                    windowName: windowName
                ))
            }
            cachedWindows = windows
        }
    }

    private func finishSelection(with selection: WindowSelection?) {
        precondition(Thread.isMainThread)
        guard !isFinishing else { return }
        isFinishing = true
        cancelWorkItem?.cancel()
        cancelWorkItem = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.teardownOverlay()
            let completion = self.completion
            self.completion = nil
            completion?(selection)
        }
    }

    private func teardownOverlay() {
        precondition(Thread.isMainThread)
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func screenFrameForAppKitBounds(_ bounds: CGRect) -> CGRect? {
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let intersection = bounds.intersection(screen.frame)
            let area = max(intersection.width, 0) * max(intersection.height, 0)
            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }
        if bestArea > 0 {
            return bestScreen?.frame
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(bounds) })?.frame
    }

    private func appKitBounds(for cgBounds: CGRect) -> CGRect {
        let primaryHeight = primaryScreenHeight()
        let converted = CGRect(
            x: cgBounds.origin.x,
            y: primaryHeight - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )
        return converted
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

}

private struct WindowInfo {
    let id: CGWindowID
    let cgBounds: CGRect
    let appKitBounds: CGRect
    let ownerName: String
    let windowName: String
}

private final class WindowPickerOverlayWindow: NSWindow {
    private let pickerView: WindowPickerOverlayView

    init(controller: WindowPickerController) {
        let frame = WindowPickerOverlayWindow.fullScreenUnionFrame()
        pickerView = WindowPickerOverlayView(controller: controller, frame: frame)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = pickerView
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            pickerView.cancelSelection()
            return
        }
        super.keyDown(with: event)
    }

    private static func fullScreenUnionFrame() -> CGRect {
        NSScreen.screens.reduce(.null) { partial, screen in
            partial.union(screen.frame)
        }
    }
}

private final class WindowPickerOverlayView: NSView {
    private weak var controller: WindowPickerController?
    private var highlightRect: CGRect?
    private var trackingAreaRef: NSTrackingArea?

    init(controller: WindowPickerController, frame: CGRect) {
        self.controller = controller
        super.init(frame: NSRect(origin: .zero, size: frame.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef = trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .inVisibleRect]
        let tracking = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(tracking)
        trackingAreaRef = tracking
    }

    override func mouseMoved(with event: NSEvent) {
        updateHighlight(for: NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        let location = NSEvent.mouseLocation
        let windowInfo = controller?.windowAtPoint(location)
        controller?.selectWindow(windowInfo)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.08).setFill()
        dirtyRect.fill()
        guard let highlightRect = highlightRect else { return }
        let path = NSBezierPath(roundedRect: highlightRect, xRadius: 8, yRadius: 8)
        NSColor.systemBlue.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.systemBlue.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    func cancelSelection() {
        controller?.cancel()
    }

    func updateHighlight(for globalPoint: CGPoint) {
        guard let window = window else { return }
        guard let windowInfo = controller?.windowAtPoint(globalPoint) else {
            highlightRect = nil
            needsDisplay = true
            return
        }
        let localRect = window.convertFromScreen(windowInfo.appKitBounds)
        highlightRect = localRect
        needsDisplay = true
    }
}
