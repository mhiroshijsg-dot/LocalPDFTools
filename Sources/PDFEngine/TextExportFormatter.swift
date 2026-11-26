/// 取り出した文字を .txt の中身にする。ページごとに見出しを付け、文字の無いページも黙って空にしない
public struct TextExportFormatter {
    /// 1 ファイル分。pages が nil なのは、まだ読んでいない（パスワードが要るなど）
    public struct FileEntry: Sendable {
        public let name: String
        public let pages: [PageText]?

        public init(name: String, pages: [PageText]?) {
            self.name = name
            self.pages = pages
        }
    }

    public init() {}

    /// 1 ファイルだけなら、ファイル名の見出しは付けない
    public func format(_ files: [FileEntry]) -> String {
        if files.count == 1 { return body(files[0]) }
        return files.map { "===== \($0.name) =====\n\n" + body($0) }.joined(separator: "\n\n")
    }

    private func body(_ file: FileEntry) -> String {
        guard let pages = file.pages else { return "（パスワードが要るため、文字を読んでいません）\n" }
        return pages.map { page in
            "--- \(page.pageNumber) ページ\(page.source == .ocr ? "（OCR）" : "") ---\n" + content(page)
        }.joined(separator: "\n\n") + "\n"
    }

    private func content(_ page: PageText) -> String {
        let text = page.text.trimmingCharacters(in: .newlines)
        switch page.source {
        case .textLayer: return text
        case .ocr: return text.isEmpty ? "（OCR で文字が見つかりませんでした）" : text
        case .none: return "（文字の層なし・OCR していません）"
        }
    }
}
