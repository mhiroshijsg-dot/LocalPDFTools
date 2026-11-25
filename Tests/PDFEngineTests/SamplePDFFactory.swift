import CoreGraphics
import Foundation

/// 検査用の PDF を合成する（個人の書類は使わない）
struct SamplePDFFactory {
    let directory: URL

    /// ページの大きさ（縦長・横長など）を変えた PDF を作る。並び順の確認に使う。
    func make(name: String, pageSizes: [CGSize]) throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw SampleError("PDF を作れません: \(name)")
        }
        for (index, size) in pageSizes.enumerated() {
            var box = CGRect(origin: .zero, size: size)
            context.beginPage(mediaBox: &box)
            let shade = CGFloat(index + 1) / CGFloat(pageSizes.count + 1)
            context.setFillColor(CGColor(red: shade, green: 0.4, blue: 1 - shade, alpha: 1))
            context.fill(CGRect(x: 20, y: 20, width: size.width / 2, height: size.height / 3))
            context.endPage()
        }
        context.closePDF()
        return url
    }

    /// しおり付きの PDF を作る。
    /// MEMO(2026-11-25・by claude): PDFKit で outlineRoot を付けて保存すると、macOS 27 ではしおりが落ちた。
    /// そこで最小の PDF を文字で書き、qpdf に目録（xref）を作り直させる。
    func makeWithOutline(name: String, qpdf: URL) throws -> URL {
        let raw = directory.appendingPathComponent("raw-" + name)
        let text = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R /Outlines 4 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] >> endobj
        4 0 obj << /Type /Outlines /First 5 0 R /Last 5 0 R /Count 1 >> endobj
        5 0 obj << /Title (Chapter 1) /Parent 4 0 R /Dest [3 0 R /Fit] >> endobj
        trailer << /Root 1 0 R /Size 6 >>
        %%EOF

        """
        try Data(text.utf8).write(to: raw)
        let url = directory.appendingPathComponent(name)
        let process = Process()
        process.executableURL = qpdf
        process.arguments = [raw.path, url.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        // 目録が無いという警告が出る（終了コード 3）のは想定どおり
        guard [0, 3].contains(process.terminationStatus) else { throw SampleError("しおり付き PDF を作れません") }
        return url
    }

    /// qpdf で暗号化した PDF を作る。userPassword が空なら「開けるが編集禁止」（ETS のスコアレポート型）。
    /// restrictions は禁止する操作の qpdf の指定（既定は編集とコピーの禁止）。
    /// MEMO(2026-11-25・by claude): Process に渡した引数の日本語は、分解した形（「パ」→「ハ」＋「゜」）に変わる。
    /// そのままだと日本語のパスワードが別の文字列になるので、引数は qpdf の `@-`（標準入力から引数を読む）で渡す。
    func encrypt(_ source: URL, name: String, userPassword: String, qpdf: URL,
                 restrictions: [String] = ["--modify=none", "--extract=n"]) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let arguments = ["--encrypt", userPassword, "owner-secret", "256"] + restrictions + ["--", source.path, url.path]
        let process = Process()
        process.executableURL = qpdf
        process.arguments = ["@-"]
        let input = Pipe()
        process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data(arguments.map { $0 + "\n" }.joined().utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SampleError("暗号化に失敗: \(name)") }
        return url
    }
}
