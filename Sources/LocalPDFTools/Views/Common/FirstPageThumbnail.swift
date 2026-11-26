import SwiftUI

/// ファイルの並びに出す、1 ページ目の小さな絵。パスワードが要る PDF は開けないので鍵の印を出す。
/// 回す予定があれば、その向きに傾けて見せる。
struct FirstPageThumbnail: View {
    let file: WorkFile

    var body: some View {
        ZStack {
            if file.isLocked {
                placeholder(symbol: "lock.fill")
            } else if let image = file.thumbnails.images[0] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                    .rotationEffect(.degrees(Double(file.displayTurns.first ?? 0) * 90))
                    .animation(.easeInOut(duration: 0.15), value: file.displayTurns.first)
            } else {
                placeholder(symbol: "doc.text")
            }
        }
        .frame(width: 38, height: 46)
        // MEMO(2026-11-26・by claude): 描くのは 1 ページ目の 1 枚だけで、行が画面に出たときに 1 回だけ。
        .task {
            if let document = file.openDocument() { file.thumbnails.load(pageIndex: 0, from: document) }
        }
    }

    private func placeholder(symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(.quaternary)
            .frame(width: 34, height: 44)
            .overlay(Image(systemName: symbol).foregroundStyle(.secondary))
    }
}
