import PDFEngine
import SwiftUI

/// 保存後の結果: 保存先・「元 → 新」の大きさ・Finder で表示
struct OutcomeView: View {
    let outcome: OperationOutcome
    @AppStorage("fileNameLimit") private var limit = 0

    var body: some View {
        let name = outcome.destination.lastPathComponent
        VStack(alignment: .leading, spacing: 6) {
            Label("保存しました", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            HStack(alignment: .top) {
                Text(outcome.destination.path)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Finder で表示") { DesktopActions.revealInFinder(outcome.destination) }
                Button {
                    DesktopActions.copy(outcome.destination.path)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .help("パスをコピー")
            }
            Text("元 \(FileSize.text(outcome.inputBytes)) → 新 \(FileSize.text(outcome.outputBytes))")
                .monospacedDigit()
            Text("ファイル名 \(OutputName.length(name)) 文字" + (limit > 0 ? "（上限 \(limit)）" : ""))
                .foregroundStyle(OutputName.exceeds(name, limit: limit) ? Color.red : Color.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
    }
}
