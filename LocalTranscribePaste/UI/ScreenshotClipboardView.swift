import SwiftUI
import AppKit

enum ScreenshotStripLayout {
    static let thumbnailWidth: CGFloat = 125
    static let thumbnailHeight: CGFloat = 99
    static let spacing: CGFloat = 20
    static let padding: CGFloat = 8
    static let margin: CGFloat = 16
    static let shadowRadius: CGFloat = 3
    static let shadowOpacity: Double = 0.16
    static let shadowOffset = CGSize(width: 0, height: 3)
    static let cornerRadius: CGFloat = 10
    static let poofDuration: Double = 0.5
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
                    onClose: { poofAndDelete(item) },
                    dragItems: { dragSourceItems(from: draggedItems) },
                    onDragEnded: { success in
                        if success {
                            deleteItems(draggedItems)
                        }
                    }
                )
                .transition(.thumbnailPop)
            }
        }
        .frame(width: stripSize.width, height: stripSize.height, alignment: .center)
        .padding(ScreenshotStripLayout.padding)
        .frame(width: stripSize.width + (ScreenshotStripLayout.padding * 2),
               height: stripSize.height + (ScreenshotStripLayout.padding * 2))
        .onChange(of: model.items) { newValue in
            let validIDs = Set(newValue.map { $0.id })
            selection = selection.intersection(validIDs)
        }
    }

    private var stripSize: CGSize {
        let count = CGFloat(model.items.count)
        let width = (count * ScreenshotStripLayout.thumbnailWidth)
            + (max(count - 1, 0) * ScreenshotStripLayout.spacing)
        let height = ScreenshotStripLayout.thumbnailHeight
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

    private func poofAndDelete(_ item: ScreenshotItem) {
        deleteItems([item])
    }
}

private struct ThumbnailEntranceEffect: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    let rotation: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .rotation3DEffect(.degrees(rotation), axis: (x: 0.0, y: 1.0, z: 0.0), perspective: 0.4)
    }
}

private struct PoofParticle {
    let angle: Double
    let distance: CGFloat
    let radius: CGFloat
}

private struct PoofBurstView: View {
    let particles: [PoofParticle]
    let duration: Double
    @State private var progress: CGFloat = 0

    init(seed: Int, duration: Double = ScreenshotStripLayout.poofDuration) {
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(seed)))
        var values: [PoofParticle] = []
        values.reserveCapacity(36)
        for _ in 0..<36 {
            let angle = Double.random(in: 0...(Double.pi * 2), using: &generator)
            let distance = CGFloat.random(in: 24...70, using: &generator)
            let radius = CGFloat.random(in: 3.0...9.0, using: &generator)
            values.append(PoofParticle(angle: angle, distance: distance, radius: radius))
        }
        self.particles = values
        self.duration = duration
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let flashProgress = min(progress * 2.5, 1.0)
            let flashAlpha = flashProgress < 1.0
                ? Double(flashProgress) * 0.85
                : Double(1 - (progress - 0.4) / 0.6) * 0.85
            let puffRadius = min(size.width, size.height) * (0.3 + (0.5 * progress))
            let puffRect = CGRect(x: center.x - puffRadius, y: center.y - puffRadius, width: puffRadius * 2, height: puffRadius * 2)
            context.fill(Path(ellipseIn: puffRect), with: .color(Color.white.opacity(max(flashAlpha, 0))))
            context.fill(Path(ellipseIn: puffRect), with: .color(Color.orange.opacity(max(flashAlpha * 0.3, 0))))

            for (index, particle) in particles.enumerated() {
                let travel = particle.distance * progress * 1.4
                let x = center.x + CGFloat(cos(particle.angle)) * travel
                let y = center.y + CGFloat(sin(particle.angle)) * travel
                let radius = max(particle.radius * (1 - progress * 0.7), 1.0)
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                let alpha = Double(1 - progress * 0.85)
                let color: Color
                switch index % 4 {
                case 0: color = Color.white.opacity(alpha * 0.9)
                case 1: color = Color.yellow.opacity(alpha * 0.85)
                case 2: color = Color.orange.opacity(alpha * 0.8)
                default: color = Color.red.opacity(alpha * 0.6)
                }
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: duration)) {
                progress = 1
            }
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234ABCD : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private extension AnyTransition {
    static var thumbnailPop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ThumbnailEntranceEffect(scale: 0.6, opacity: 0.0, rotation: -12),
                identity: ThumbnailEntranceEffect(scale: 1.0, opacity: 1.0, rotation: 0)
            )
            .combined(with: .offset(x: 0, y: 10)),
            removal: .opacity
        )
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
        thumbnail
            .overlay(selectionOverlay)
            .clipShape(RoundedRectangle(cornerRadius: ScreenshotStripLayout.cornerRadius, style: .continuous))
            .frame(width: ScreenshotStripLayout.thumbnailWidth, height: ScreenshotStripLayout.thumbnailHeight)
            .contentShape(RoundedRectangle(cornerRadius: ScreenshotStripLayout.cornerRadius, style: .continuous))
            .overlay(
                DragSourceOverlay(
                    onTap: onTap,
                    dragItems: dragItems,
                    onDragEnded: onDragEnded
                )
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 18, height: 18)
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
                .frame(width: ScreenshotStripLayout.thumbnailWidth, height: ScreenshotStripLayout.thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: ScreenshotStripLayout.cornerRadius, style: .continuous))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(Text("?").foregroundColor(.secondary))
                .clipShape(RoundedRectangle(cornerRadius: ScreenshotStripLayout.cornerRadius, style: .continuous))
        }
    }

    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: ScreenshotStripLayout.cornerRadius, style: .continuous)
            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
