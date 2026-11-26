import PDFEngine
import SwiftUI

/// 文字の抽出のカードの中身: 「文字を見る…」と、文字の層のあり・なしのページ数
struct TextExtractionDetailsView: View {
    let workspace: Workspace
    @Binding var showsTextSheet: Bool

    var body: some View {
        let files = workspace.files
        let layer = files.reduce(0) { $0 + $1.textPageCount(.textLayer) }
        let missing = files.reduce(0) { $0 + $1.textPageCount(.none) }
        let ocr = files.reduce(0) { $0 + $1.textPageCount(.ocr) }
        let unread = files.filter { $0.isLocked && $0.pageTexts == nil }.count

        Button {
            showsTextSheet = true
        } label: {
            Label("文字を見る…", systemImage: "doc.text.magnifyingglass")
        }
        .disabled(files.isEmpty)
        if workspace.text.isReading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("文字の層を調べています…").foregroundStyle(.secondary)
            }
        } else if !files.isEmpty {
            HStack(spacing: 6) {
                if layer > 0 { Badge(text: "文字の層 \(layer) ページ", symbol: "doc.text", tint: .teal) }
                if missing > 0 { Badge(text: "層なし \(missing) ページ", symbol: "photo", tint: .secondary) }
                if ocr > 0 { Badge(text: "OCR 済み \(ocr)", symbol: "text.viewfinder", tint: .teal) }
            }
            if missing > 0 {
                Text("層なしのページ（スキャンなど）は、シートで OCR できます").foregroundStyle(.secondary)
            }
            if unread > 0 {
                Text("パスワードが要る PDF \(unread) つは、シートで開いて読めます").foregroundStyle(.secondary)
            }
        }
        Text("PDF は変わりません。文字はシートでコピー・保存します").foregroundStyle(.secondary)
    }
}
