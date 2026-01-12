import SwiftUI

enum IndicatorMode {
    case recording
    case pasteReady
}

struct RecordingIndicatorView: View {
    let mode: IndicatorMode

    private var text: String {
        switch mode {
        case .recording:
            return "Recording"
        case .pasteReady:
            return "Paste ready"
        }
    }

    private var color: Color {
        switch mode {
        case .recording:
            return .red
        case .pasteReady:
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            indicator
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
    }

    @ViewBuilder
    private var indicator: some View {
        if mode == .recording {
            WaveformBars(color: color)
        } else {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }
}

private struct WaveformBars: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    let phase = t * 2.2 + Double(index) * 0.8
                    let amplitude = 0.3 + 0.7 * abs(sin(phase))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: 6 + amplitude * 12)
                }
            }
            .frame(width: 24, height: 18, alignment: .center)
        }
    }
}
