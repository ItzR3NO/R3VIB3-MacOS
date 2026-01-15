import SwiftUI
import AppKit

enum ScreenshotStripLayout {
    static let thumbnailSize: CGFloat = 72
    static let spacing: CGFloat = 20
    static let padding: CGFloat = 8
    static let margin: CGFloat = 16
    static let shadowRadius: CGFloat = 3
    static let shadowOpacity: Double = 0.16
    static let shadowOffset = CGSize(width: 0, height: 3)
}

final class ScreenshotStripModel: ObservableObject {
    @Published var items: [ScreenshotItem] = []
}

struct ScreenshotClipboardView: View {
    @ObservedObject var model: ScreenshotStripModel
    @EnvironmentObject var appState: AppState
    @State private var selection: Set<UUID> = []

    var body: some View {
        HStack(spacing: ScreenshotStripLayout.spacing) {
            ForEach(model.items) { item in
                let draggedItems = dragItems(for: item)
                ScreenshotThumbnail(
                    item: item,
                    isSelected: selection.contains(item.id),
                    onTap: { toggleSelection(for: item) },
                    onClose: { deleteItems([item]) },
                    dragItems: { dragSourceItems(from: draggedItems) },
                    onDragEnded: { success in
                        if success {
                            deleteItems(draggedItems)
                        }
                    }
                )
            }
        }
        .frame(width: stripSize.width, height: stripSize.height, alignment: .center)
        .padding(ScreenshotStripLayout.padding)
        .frame(width: stripSize.width + (ScreenshotStripLayout.padding * 2),
               height: stripSize.height + (ScreenshotStripLayout.padding * 2))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.items)
        .onChange(of: model.items) { newValue in
            let validIDs = Set(newValue.map { $0.id })
            selection = selection.intersection(validIDs)
        }
    }

    private var stripSize: CGSize {
        let count = CGFloat(model.items.count)
        let width = (count * ScreenshotStripLayout.thumbnailSize)
            + (max(count - 1, 0) * ScreenshotStripLayout.spacing)
        let height = ScreenshotStripLayout.thumbnailSize
        return CGSize(width: width, height: height)
    }

    private func toggleSelection(for item: ScreenshotItem) {
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    private func dragItems(for item: ScreenshotItem) -> [ScreenshotItem] {
        if selection.isEmpty || !selection.contains(item.id) {
            return [item]
        }
        return model.items.filter { selection.contains($0.id) }
    }

    private func dragSourceItems(from items: [ScreenshotItem]) -> [DragSourceItem] {
        items.map { item in
            DragSourceItem(url: item.url, previewImage: NSImage(contentsOf: item.url))
        }
    }

    private func deleteItems(_ items: [ScreenshotItem]) {
        appState.deleteScreenshots(items)
    }
}

private struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    let isSelected: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    let dragItems: () -> [DragSourceItem]
    let onDragEnded: (Bool) -> Void

    var body: some View {
        ZStack {
            thumbnail
                .overlay(selectionOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(width: ScreenshotStripLayout.thumbnailSize, height: ScreenshotStripLayout.thumbnailSize)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            DragSourceOverlay(
                onTap: onTap,
                dragItems: dragItems,
                onDragEnded: onDragEnded
            )
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .shadow(
            color: Color.black.opacity(ScreenshotStripLayout.shadowOpacity),
            radius: ScreenshotStripLayout.shadowRadius,
            x: ScreenshotStripLayout.shadowOffset.width,
            y: ScreenshotStripLayout.shadowOffset.height
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = NSImage(contentsOf: item.url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: ScreenshotStripLayout.thumbnailSize, height: ScreenshotStripLayout.thumbnailSize)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(Text("?").foregroundColor(.secondary))
        }
    }

    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
