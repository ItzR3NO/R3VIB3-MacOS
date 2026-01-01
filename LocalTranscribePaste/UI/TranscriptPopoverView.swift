import SwiftUI

struct TranscriptPopoverView: View {
    @EnvironmentObject var appState: AppState
    let text: String
    let isMessageOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                Text(text.isEmpty ? "(empty)" : text)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 320, height: 120)

            if isMessageOnly {
                EmptyView()
            } else {
                HStack {
                    Button("Copy") { appState.copyLastTranscript() }
                    Button("Paste") { appState.pasteLastTranscript() }
                    Button("Clear") { appState.clearTranscript() }
                    Button("Retry") { appState.retryTranscription() }
                }
            }
        }
        .padding(12)
    }
}
