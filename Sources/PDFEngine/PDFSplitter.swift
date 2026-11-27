import Foundation

/// 1 つの PDF を、ページの範囲ごとに別々の PDF にする。
/// 中身は範囲ごとに `qpdf --empty --pages 入力 1-3 -- 出力.pdf`。同じ大きさで先頭から区切るときは
/// `qpdf --split-pages=N` 1 回でまとめて作る（ページの多い PDF でも qpdf を何百回も呼ばないように）。
/// ページを作り直さないので、文字・画質・URL のリンクは変わらない。
/// MEMO(2026-11-27・by claude): 実測（qpdf 12.4）で、どちらの形でも暗号化・しおりは引き継がれず、ページ番号の付け方（/PageLabels）は残った。
/// 入力そのものを土台にする形（`qpdf 入力 --pages . 1-3 --`）なら暗号化は残るが、しおりも残って
/// 無いページを指したままになるので使わない。暗号化が外れることは結合と同じく実行前に確認する。
public struct PDFSplitter {
    let runner: QPDFRunner

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// directory（空のフォルダを新しく作る）に、ranges の順に 1 つずつ PDF を作る。作ったファイルを ranges と同じ順で返す
    public func splitFile(_ input: URL, ranges: [ClosedRange<Int>], pageCount: Int,
                          into directory: URL) async throws -> (files: [URL], warnings: [String]) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let size = SplitPlan.uniformChunkSize(of: ranges, pageCount: pageCount), ranges.count > 1 {
            return try await splitUniformly(input, size: size, expected: ranges.count, into: directory)
        }
        var files: [URL] = []
        var warnings: [String] = []
        for (index, range) in ranges.enumerated() {
            let output = directory.appendingPathComponent("piece-\(index + 1).pdf")
            // パスは「/」で始まる絶対パスなので、qpdf がページ範囲やオプションと取り違えることはない
            let arguments = ["--empty", "--pages", input.path, "\(range.lowerBound)-\(range.upperBound)", "--", output.path]
            warnings += try await runner.runChecked(arguments).warningLines
            files.append(output)
        }
        return (files, warnings)
    }

    /// qpdf --split-pages=N。出力の名前は piece-01-04.pdf のように最初のページの番号がゼロ埋めで付くので、名前の順に並べる
    private func splitUniformly(_ input: URL, size: Int, expected: Int,
                                into directory: URL) async throws -> (files: [URL], warnings: [String]) {
        let pattern = directory.appendingPathComponent("piece-%d.pdf")
        let warnings = try await runner.runChecked(["--split-pages=\(size)", input.path, pattern.path]).warningLines
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "pdf" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count == expected else { throw EngineError.outputNotCreated }
        return (files, warnings)
    }
}
