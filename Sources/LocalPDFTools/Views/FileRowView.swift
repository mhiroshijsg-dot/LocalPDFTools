import PDFEngine
import SwiftUI

/// ファイルの並びの 1 行: 順番・1 ページ目の絵・名前・ページ数と大きさ・札（暗号化・しおり・回転）・外すボタン
struct FileRowView: View {
    let number: Int
    let file: WorkFile
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.semibold)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 22)
            FirstPageThumbnail(file: file)
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.body.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(details)
                        .font(.callout).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .help(file.pageCount == nil ? "パスワードが要るので、開くまでページ数は分かりません" : "")
                    badges
                }
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isHovered ? 1 : 0.35)
            .help("この PDF を外す")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var details: String {
        let pages = file.pageCount.map { "\($0) ページ" } ?? "— ページ"
        return "\(pages) · \(FileSize.text(file.byteSize))"
    }

    @ViewBuilder
    private var badges: some View {
        switch file.encryption.status {
        case .notEncrypted: EmptyView()
        case .restricted:
            Badge(text: "制限あり", symbol: "lock", tint: .orange).help(file.encryptionDetail)
        case .passwordRequired:
            Badge(text: "要パスワード", symbol: "lock.fill", tint: .red).help(file.encryptionDetail)
        }
        if file.hasOutline { Badge(text: "しおりあり", symbol: "bookmark.fill") }
        if file.rotatedPageCount > 0 {
            Badge(text: "\(file.rotatedPageCount) ページ回転", symbol: "rotate.right", tint: .blue)
        }
    }
}
