import Foundation

/// 段階 5（重い図を画像にする）の検査用の PDF を合成する。
/// TeX の `\includegraphics` で散布図を入れた論文に似せる: 散布図は独立した部品（Form XObject）で、ページの本文の文字の下に置く。
/// MEMO(2026-11-26・by claude): Core Graphics で別の PDF のページを描くと、macOS 27 では図が部品にならずページに直接書かれた。
/// そこで PDF を文字で書き、qpdf に目録（xref）を作り直させる（makeLinePlot と同じ方法）。
/// SamplePDFFactory は段階 3 のセッションが書き換え中だったので、別の型にした。
struct FigureSampleFactory {
    let directory: URL
    let qpdf: URL

    /// 本文の文字と、点を points 個打った散布図（400 × 300 の図を scale 倍で置く）の論文風の PDF（letter 1 ページ）。
    /// placements の数だけ、同じ図を縦に並べて置く
    func makePaper(name: String, points: Int, scale: Double = 0.5, placements: Int = 1) throws -> URL {
        var figure = "0 G 1 w 40 30 340 250 re S\n"
        // 決まった並びの点（乱数を使わないので、何度作っても同じ PDF になる）
        var state: UInt32 = 12_345
        func next() -> Double {
            state = state &* 1_103_515_245 &+ 12_345
            return Double((state >> 8) & 0xFFFF) / 65_535
        }
        let colors = ["0.1 0.2 0.3 rg", "0.9 0.5 0.2 rg", "0.2 0.3 0.8 rg"]
        for index in 0..<points {
            let x = 40 + next() * 340
            let y = 30 + (0.2 + 0.6 * (x - 40) / 340 + (next() - 0.5) * 0.3) * 250
            if index % 100 == 0 { figure += colors[(index / 100) % 3] + "\n" }
            figure += String(format: "%.2f %.2f 1.6 1.6 re f\n", x, y)
        }
        figure += "0 g BT /F1 10 Tf 180 8 Td (Scatter) Tj ET\n"

        var page = "BT /F1 14 Tf 72 740 Td (Body text stays selectable) Tj ET\n"
        for index in 0..<placements {
            page += "q \(scale) 0 0 \(scale) 100 \(420 - index * 260) cm /Fm1 Do Q\n"
        }

        let raw = directory.appendingPathComponent("raw-" + name)
        let text = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> /XObject << /Fm1 6 0 R >> >> >> endobj
        4 0 obj << /Length \(page.utf8.count) >> stream
        \(page)endstream endobj
        5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
        6 0 obj << /Type /XObject /Subtype /Form /BBox [0 0 400 300] /Resources << /Font << /F1 5 0 R >> >> /Length \(figure.utf8.count) >> stream
        \(figure)endstream endobj
        trailer << /Root 1 0 R /Size 7 >>
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
        guard [0, 3].contains(process.terminationStatus) else { throw SampleError("図の PDF を作れません: \(name)") }
        try? FileManager.default.removeItem(at: raw)
        return url
    }
}
