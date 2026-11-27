import Foundation
import PDFEngine

/// 取り出した文字を .txt に保存する流れ。「まとめて 1 つ」と「ファイルごと」（ファイルの数だけ保存ダイアログ）
@MainActor
struct TextExportRunner {
    let workspace: Workspace
    private let formatter = TextExportFormatter()
    private var model: TextExtractionModel { workspace.text }

    /// 全ファイルの文字を 1 つの .txt に（ファイル名とページ番号の見出し付き）
    func saveCombined() {
        let files = workspace.files
        guard let first = files.first else { return }
        let name = files.count == 1 ? SuggestedName.text(first.url) : SuggestedName.mergedText(top: first.url)
        guard let destination = FilePanels().chooseTextDestination(suggestedName: name, in: folder(for: first)) else { return }
        model.saved = []
        model.messages = []
        write(formatter.format(files.map(entry)), to: destination)
    }

    /// ファイルごとに .txt を保存する。キャンセルしたファイルは飛ばして、最後に知らせる
    func saveEach() {
        model.saved = []
        model.messages = []
        var skipped: [String] = []
        for file in workspace.files {
            guard let destination = FilePanels().chooseTextDestination(
                suggestedName: SuggestedName.text(file.url), in: folder(for: file),
                message: String(localized: "「\(file.fileName)」の文字の保存先")) else {
                skipped.append(file.fileName)
                continue
            }
            write(formatter.format([entry(file)]), to: destination)
        }
        if !skipped.isEmpty {
            model.messages.append(.note(String(localized: "保存しなかったファイル: \(ListText.join(skipped))")))
        }
    }

    private func entry(_ file: WorkFile) -> TextExportFormatter.FileEntry {
        TextExportFormatter.FileEntry(name: file.fileName, pages: file.pageTexts)
    }

    /// 「変更…」で選んだ保存先があればそこ、無ければそのファイルのフォルダ
    private func folder(for file: WorkFile) -> URL {
        workspace.chosenFolder ?? file.url.deletingLastPathComponent()
    }

    /// 一時ファイルに書いてから置き換える（失敗しても既にあるファイルを壊さない）
    private func write(_ text: String, to destination: URL) {
        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            model.saved.append(destination)
        } catch {
            model.messages.append(.error(String(localized: "保存できませんでした: \(destination.path)（\(error.localizedDescription)）")))
        }
    }
}
