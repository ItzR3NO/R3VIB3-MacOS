import SwiftUI
import AppKit

struct DragSourceItem {
    let url: URL
    let previewImage: NSImage?
}

struct DragSourceOverlay: NSViewRepresentable {
    let onTap: () -> Void
    let dragItems: () -> [DragSourceItem]
    let onDragEnded: (Bool) -> Void

    func makeNSView(context: Context) -> DragSourceOverlayView {
        let view = DragSourceOverlayView()
        view.onTap = onTap
        view.dragItemsProvider = dragItems
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: DragSourceOverlayView, context: Context) {
        nsView.onTap = onTap
        nsView.dragItemsProvider = dragItems
        nsView.onDragEnded = onDragEnded
    }
}

final class DragSourceOverlayView: NSView, NSDraggingSource {
    var onTap: () -> Void = {}
    var dragItemsProvider: () -> [DragSourceItem] = { [] }
    var onDragEnded: (Bool) -> Void = { _ in }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        let startPoint = event.locationInWindow
        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { return }
            switch nextEvent.type {
            case .leftMouseDragged:
                let delta = hypot(nextEvent.locationInWindow.x - startPoint.x, nextEvent.locationInWindow.y - startPoint.y)
                if delta > 3 {
                    startDragging(event: event)
                    return
                }
            case .leftMouseUp:
                onTap()
                return
            default:
                break
            }
        }
    }

    private func startDragging(event: NSEvent) {
        let items = dragItemsProvider()
        guard !items.isEmpty else { return }
        let draggingItems: [NSDraggingItem] = items.map { item in
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(item.url.path, forType: .string)
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let image = item.previewImage ?? NSWorkspace.shared.icon(forFile: item.url.path)
            let size = NSSize(width: 64, height: 64)
            let frame = NSRect(origin: .zero, size: size)
            draggingItem.setDraggingFrame(frame, contents: image)
            return draggingItem
        }
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragEnded(operation != [])
    }
}
