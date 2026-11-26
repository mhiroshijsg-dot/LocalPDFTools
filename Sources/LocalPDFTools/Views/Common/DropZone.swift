import SwiftUI

/// PDF がまだ無いときの大きな案内: 「ここにドロップ」と「ファイルを選ぶ…」
struct DropZone: View {
    let allowsMultiple: Bool
    let onOpen: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 4) {
                Text("PDF をここにドロップ").font(.title2.weight(.semibold))
                Text(allowsMultiple ? "いくつでもまとめて入れられます" : "1 つ入れてください")
                    .foregroundStyle(.secondary)
            }
            Button {
                let urls = FilePanels().choosePDFs(allowsMultiple: allowsMultiple)
                if !urls.isEmpty { onOpen(urls) }
            } label: {
                Text("ファイルを選ぶ…").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Label("PDF はこの Mac の中だけで処理します", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(.quaternary)
        )
    }
}
