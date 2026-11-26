import Foundation
import Observation
import PDFEngine

/// 文字の抽出の状態: 文字の層を読む・OCR（押したときだけ）・.txt の保存の結果
@MainActor
@Observable
final class TextExtractionModel {
    /// 文字の層を読んでいるファイル
    private var reading: Set<WorkFile.ID> = []
    /// OCR しているファイルと、まだ読んでいないページ
    private(set) var ocrFile: WorkFile.ID?
    private(set) var ocrRemaining: [Int] = []
    private(set) var ocrDone = 0
    private(set) var ocrTotal = 0
    private var ocrTask: Task<Void, Never>?
    /// 保存した .txt と、保存についてのお知らせ（シートの下に出す）
    var saved: [URL] = []
    var messages: [UserMessage] = []

    var isOCRRunning: Bool { ocrTask != nil }
    var isReading: Bool { !reading.isEmpty }

    // MARK: 文字の層

    /// まだ読んでいないファイルの文字の層を読む（パスワードが要るものは飛ばす。シートで頼まれたときに読む）
    func readLayers(_ files: [WorkFile]) async {
        let targets = files.filter { $0.pageTexts == nil && $0.textError == nil && !$0.isLocked && !reading.contains($0.id) }
        targets.forEach { reading.insert($0.id) }
        for file in targets {
            await read(file)
            reading.remove(file.id)
        }
    }

    /// パスワードが要るファイルを読む（パスワードは小窓で聞き、qpdf に渡したらすぐ手放す）
    func readLocked(_ file: WorkFile) async {
        guard !reading.contains(file.id) else { return }
        reading.insert(file.id)
        defer { reading.remove(file.id) }
        file.textError = nil
        await read(file)
    }

    private func read(_ file: WorkFile) async {
        do {
            file.pageTexts = try await extractor().readTextLayer(file.url, askPassword: PasswordPrompt.ask)
        } catch EngineError.passwordCancelled {
            // やめた: 読まないまま（もう一度押せば読める）
        } catch {
            file.textError = error.localizedDescription
        }
    }

    // MARK: OCR

    /// 指定したページを OCR する（押したときだけ）。rotation は作業台の回転の指定（回転がオフなら渡さない）
    func startOCR(_ file: WorkFile, pages: [Int], quarterTurns: [Int]) {
        guard !pages.isEmpty, !isOCRRunning else { return }
        ocrFile = file.id
        ocrRemaining = pages
        ocrDone = 0
        ocrTotal = pages.count
        file.textError = nil
        ocrTask = Task {
            defer {
                ocrTask = nil
                ocrFile = nil
                ocrRemaining = []
            }
            do {
                try await extractor().recognize(file.url, pageIndexes: pages, quarterTurns: quarterTurns,
                                                askPassword: PasswordPrompt.ask) { page in
                    if let index = file.pageTexts?.firstIndex(where: { $0.pageIndex == page.pageIndex }) {
                        file.pageTexts?[index] = page
                    }
                    self.ocrRemaining.removeAll { $0 == page.pageIndex }
                    self.ocrDone += 1
                }
            } catch is CancellationError {
                // 中止した: 読み終えたページの結果は残す
            } catch EngineError.passwordCancelled {
                // やめた
            } catch {
                file.textError = error.localizedDescription
            }
        }
    }

    func cancelOCR() {
        ocrTask?.cancel()
    }

    /// このページを今読んでいるか、これから読むか
    func isQueued(_ file: WorkFile, page: Int) -> Bool {
        ocrFile == file.id && ocrRemaining.contains(page)
    }

    /// ファイルを外したとき: そのファイルを読んでいたら止める
    func forget(_ file: WorkFile) {
        if ocrFile == file.id { cancelOCR() }
    }

    func reset() {
        cancelOCR()
        saved = []
        messages = []
    }

    private func extractor() throws -> PDFTextExtractor {
        PDFTextExtractor(runner: try QPDFRunner.locate())
    }
}
