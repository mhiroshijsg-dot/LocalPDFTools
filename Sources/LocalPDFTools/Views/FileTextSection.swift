import PDFEngine
import SwiftUI

/// 文字の抽出のシートの、ファイル 1 つ分（見出し・まとめてコピー / OCR・ページごとの文字）
struct FileTextSection: View {
    let number: Int
    let file: WorkFile
    let workspace: Workspace

    private var model: TextExtractionModel { workspace.text }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.callout.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.secondary))
                Text(file.fileName).font(.headline).lineLimit(1).truncationMode(.middle)
                if let pages = file.pageTexts { Text("\(pages.count) ページ").foregroundStyle(.secondary) }
                Spacer()
                if file.pageTexts != nil {
                    let missing = file.pagesNeedingOCR
                    if !missing.isEmpty {
                        Button {
                            workspace.startOCR(file, pages: missing)
                        } label: {
                            Label("層なしのページを OCR（\(missing.count)）", systemImage: "text.viewfinder")
                        }
                        .controlSize(.small)
                        .disabled(model.isOCRRunning)
                    }
                    Button {
                        DesktopActions.copy(TextExportFormatter().format([.init(name: file.fileName, pages: file.pageTexts)]))
                    } label: {
                        Label("すべてコピー", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)
                }
            }
            if file.encryption.deniedPermissions?.contains(.extract) == true {
                Label("この PDF は文字のコピーが禁止されています。本人が権利を持つ書類にだけ使ってください。", systemImage: "lock")
                    .font(.callout).foregroundStyle(.orange)
            }
            if let error = file.textError {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.callout).foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            if let pages = file.pageTexts {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(pages, id: \.pageIndex) { page in
                        PageTextView(page: page,
                                     isQueued: model.isQueued(file, page: page.pageIndex),
                                     canStartOCR: !model.isOCRRunning) {
                            workspace.startOCR(file, pages: [page.pageIndex])
                        }
                    }
                }
            } else if file.isLocked {
                HStack(spacing: 10) {
                    Label("開くのにパスワードが要ります。パスワードはここで 1 回だけ聞き、保存しません。", systemImage: "lock.fill")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("パスワードを入れて読む…") {
                        Task { await model.readLocked(file) }
                    }
                    .controlSize(.small)
                    .disabled(model.isReading)
                }
            } else if file.textError == nil {
                ProgressView().controlSize(.small)
                    .task { await model.readLayers([file]) }
            }
        }
    }
}
