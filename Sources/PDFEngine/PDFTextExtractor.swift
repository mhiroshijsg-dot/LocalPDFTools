import CoreGraphics
import Foundation
import PDFKit

/// PDF の文字を取り出す。文字の層があるページは PDFKit でそのまま取り出し、
/// 無いページは頼まれたときだけ画像にして Vision で読む（OCR）。元のファイルは変えない。
public struct PDFTextExtractor {
    let runner: QPDFRunner
    let renderer: PageImageRenderer
    let recognizer = TextRecognizer()
    let assembler = OCRLineAssembler()

    public init(runner: QPDFRunner, renderer: PageImageRenderer = PageImageRenderer()) {
        self.runner = runner
        self.renderer = renderer
    }

    /// 全ページの文字の層を読む。層が無いページは source が .none（OCR はしない）
    public func readTextLayer(_ url: URL, askPassword: PDFPipeline.PasswordProvider) async throws -> [PageText] {
        try await withDocument(url, askPassword: askPassword) { document in
            var pages: [PageText] = []
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                let text = document.page(at: index)?.string ?? ""
                let hasLayer = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                pages.append(PageText(pageIndex: index, source: hasLayer ? .textLayer : .none, text: hasLayer ? text : ""))
            }
            return pages
        }
    }

    /// 指定したページを OCR する。1 ページ読むごとに onPage を呼ぶ（途中で止められる）。
    /// quarterTurns はページごとに時計回りに足す 90° の回数（作業台の回転の指定。足りない分は 0）
    public func recognize(_ url: URL, pageIndexes: [Int], quarterTurns: [Int],
                          askPassword: PDFPipeline.PasswordProvider,
                          onPage: @MainActor (PageText) -> Void) async throws {
        try await withDocument(url, askPassword: askPassword) { document in
            for index in pageIndexes {
                try Task.checkCancellation()
                guard let page = document.page(at: index)?.pageRef else {
                    throw EngineError.unreadablePDF(path: url.path)
                }
                let turns = quarterTurns.indices.contains(index) ? quarterTurns[index] : 0
                guard let image = renderer.render(page, extraQuarterTurns: turns) else {
                    throw EngineError.pageNotRendered(page: index + 1, path: url.path)
                }
                let text = assembler.assemble(try recognizer.recognize(image))
                await onPage(PageText(pageIndex: index, source: .ocr, text: text))
            }
        }
    }

    /// 開いて body に渡す。開くのにパスワードが要るときだけ聞き、違っていたら聞き直す。
    /// MEMO(2026-11-26・by claude): PDFKit の unlock は、日本語のパスワードの AES-256 の PDF を正しいパスワードでも開けなかった
    /// （Core Graphics の解錠なら開けるが、それでは PDFKit で文字を取り出せない）。そこで作業台の解除と同じく、
    /// qpdf に標準入力でパスワードを渡して一時フォルダに解除した写しを作り、それを読んで、終わったら（失敗しても）すぐ消す。
    /// パスワードは qpdf に渡したら手放す（計画 §13.9）。
    func withDocument<T>(_ url: URL, askPassword: PDFPipeline.PasswordProvider,
                         _ body: (PDFDocument) async throws -> T) async throws -> T {
        guard let document = PDFDocument(url: url) else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        guard document.isLocked else { return try await body(document) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPDFTools-text-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let unlocked = directory.appendingPathComponent("unlocked.pdf")
        let decryptor = PDFDecryptor(runner: runner)
        var isRetry = false
        while true {
            guard let password = await askPassword(url, isRetry) else {
                throw EngineError.passwordCancelled(path: url.path)
            }
            do {
                _ = try await decryptor.decryptFile(url, password: password, into: unlocked)
                break
            } catch EngineError.wrongPassword {
                isRetry = true
            }
        }
        guard let opened = PDFDocument(url: unlocked) else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        return try await body(opened)
    }
}
