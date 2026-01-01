import SwiftUI

enum IndicatorMode {
    case recording
    case pasteReady
}

struct RecordingIndicatorView: View {
    let mode: IndicatorMode
    @State private var pulse = false

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
            ZStack {
                Circle()
                    .fill(color.opacity(mode == .recording ? 0.25 : 0.18))
                    .frame(width: 20, height: 20)
                    .scaleEffect(mode == .recording ? (pulse ? 1.2 : 0.7) : 0.8)
                    .opacity(mode == .recording ? (pulse ? 0.9 : 0.2) : 0.4)
                    .animation(mode == .recording ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .onAppear { pulse = (mode == .recording) }
        .onChange(of: mode) { newValue in
            pulse = (newValue == .recording)
        }
    }
}
