import PDFEngine
import SwiftUI

/// 保存後の結果: 保存した名前と場所・「元 → 新」の大きさ・ファイル名の文字数・Finder で表示
struct OutcomeView: View {
    let outcome: OperationOutcome
    @AppStorage("fileNameLimit") private var limit = 0

    var body: some View {
        let name = outcome.destination.lastPathComponent
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 4) {
                Text("保存しました").font(.callout).foregroundStyle(.secondary)
                Text(name).font(.body.weight(.semibold)).textSelection(.enabled)
                Text(outcome.destination.deletingLastPathComponent().path)
                    .font(.callout).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 14) {
                    Label("元 \(FileSize.text(outcome.inputBytes)) → 新 \(FileSize.text(outcome.outputBytes))",
                          systemImage: "internaldrive")
                    Label("ファイル名 \(OutputName.length(name)) 文字" + (limit > 0 ? "（上限 \(limit)）" : ""),
                          systemImage: "character.cursor.ibeam")
                        .foregroundStyle(OutputName.exceeds(name, limit: limit) ? Color.red : Color.secondary)
                }
                .font(.callout).monospacedDigit()
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Button("Finder で表示") { DesktopActions.revealInFinder(outcome.destination) }
                Button {
                    DesktopActions.copy(outcome.destination.path)
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
