import Foundation

/// 複数の PDF を、並べた順に 1 つにまとめる。
/// 中身は `qpdf --empty --pages a.pdf b.pdf -- 出力.pdf`。ページを作り直さないので、文字・画質・URL のリンクは変わらない。
/// MEMO(2026-11-25・by claude): 実測で、しおり（目次）と文書内のリンク（目次や参照からの飛び先）は qpdf の結合で消えると確認した。
/// 画面でそのことを知らせる（しおりを残す処理は今は作らない）。
public struct PDFMerger {
    let runner: QPDFRunner
    let writer = OutputWriter()

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    public func merge(_ inputs: [URL], to destination: URL) async throws -> OperationOutcome {
        try await writer.write(to: destination, inputs: inputs) { temporary in
            // パスはすべて「/」で始まる絶対パスなので、qpdf がページ範囲やオプションと取り違えることはない
            let arguments = ["--empty", "--pages"] + inputs.map(\.path) + ["--", temporary.path]
            return try await runner.runChecked(arguments).warningLines
        }
    }
}
