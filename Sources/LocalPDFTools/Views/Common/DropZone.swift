import SwiftUI

/// 「ここに PDF をドロップ」の枠と「開く…」ボタン
struct DropZone: View {
    let prompt: String
    let allowsMultiple: Bool
    let onOpen: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(prompt).foregroundStyle(.secondary)
            Button("開く…") {
                let urls = FilePanels().choosePDFs(allowsMultiple: allowsMultiple)
                if !urls.isEmpty { onOpen(urls) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
        )
    }
}
