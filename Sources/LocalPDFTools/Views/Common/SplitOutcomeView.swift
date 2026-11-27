import PDFEngine
import SwiftUI

/// 分割して保存した後の結果: 作ったフォルダの名前と場所・ファイルの数・大きさ（合計と一番大きいもの）・一覧・Finder で表示
struct SplitOutcomeView: View {
    let outcome: SplitOutcome
    @AppStorage("fileNameLimit") private var limit = 0

    var body: some View {
        let names = outcome.pieces.map(\.url.lastPathComponent)
        let longest = names.max { OutputName.length($0) < OutputName.length($1) } ?? ""
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 4) {
                Text("新しいフォルダに \(outcome.pieces.count) つの PDF を保存しました").font(.callout).foregroundStyle(.secondary)
                Text(outcome.folder.lastPathComponent).font(.body.weight(.semibold)).textSelection(.enabled)
                Text(outcome.folder.deletingLastPathComponent().path)
                    .font(.callout).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 14) {
                    Text("元 \(FileSize.text(outcome.inputBytes)) → 合計 \(FileSize.text(outcome.totalBytes))")
                    // 提出先の上限は 1 ファイルごとに効くので、一番大きいものも出す
                    Text("一番大きいファイル \(FileSize.text(outcome.largestBytes))")
                    Text("ファイル名 最長 \(OutputName.length(longest)) 文字" + (limit > 0 ? "（上限 \(limit)）" : ""))
                        .foregroundStyle(OutputName.exceeds(longest, limit: limit) ? Color.red : Color.secondary)
                }
                .font(.callout).monospacedDigit()
                .padding(.top, 2)
                DisclosureGroup("ファイルの一覧") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(outcome.pieces, id: \.url) { piece in
                            HStack {
                                Text(piece.url.lastPathComponent).textSelection(.enabled)
                                Spacer()
                                Text("\(piece.pages.count) ページ · \(FileSize.text(piece.bytes))")
                                    .foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Button("Finder で表示") { DesktopActions.revealInFinder(outcome.folder) }
                Button {
                    DesktopActions.copy(outcome.folder.path)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("パスをコピー")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.green.opacity(0.09))
        )
    }
}
