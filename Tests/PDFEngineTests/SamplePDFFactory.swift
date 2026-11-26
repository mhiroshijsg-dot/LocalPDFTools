import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

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

    /// 画像入りの PDF（letter 1 ページ）:
    /// - 写真風の JPEG（1275×900 ピクセル）を 306×216 ポイントに置く → 300 ppi
    /// - 灰色の可逆圧縮の画像（600×400 ピクセル）を 288×192 ポイントに置く → 150 ppi
    /// MEMO(2026-11-26・by claude): Core Graphics は JPEG から読んだ画像を、作り直さずに JPEG のまま PDF に入れる。
    func makeWithImages(name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else { throw SampleError("PDF を作れません: \(name)") }
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        context.beginPage(mediaBox: &box)
        context.draw(try jpegImage(pattern(width: 1275, height: 900, gray: false)),
                     in: CGRect(x: 40, y: 400, width: 306, height: 216))
        context.draw(try pattern(width: 600, height: 400, gray: true), in: CGRect(x: 40, y: 40, width: 288, height: 192))
        context.endPage()
        context.closePDF()
        return url
    }

    /// 別の PDF の 1 ページ目を、縮めて図（Form XObject）として置いた PDF。中の画像はページ上でより細かくなる
    func makeWithNestedPage(name: String, source: URL, scale: CGFloat) throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard let sourceDocument = CGPDFDocument(source as CFURL), let page = sourceDocument.page(at: 1),
              let context = CGContext(url as CFURL, mediaBox: nil, nil) else { throw SampleError("PDF を作れません: \(name)") }
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        context.beginPage(mediaBox: &box)
        context.scaleBy(x: scale, y: scale)
        context.drawPDFPage(page)
        context.endPage()
        context.closePDF()
        return url
    }

    /// 細かい模様の画像（JPEG にしてもそれなりの大きさになるように）
    private func pattern(width: Int, height: Int, gray: Bool) throws -> CGImage {
        let space = gray ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
        let info = gray ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: info) else { throw SampleError("画像を作れません") }
        for y in stride(from: 0, to: height, by: 6) {
            for x in stride(from: 0, to: width, by: 6) {
                let v = CGFloat((x * 7 + y * 13) % 255) / 255
                context.setFillColor(CGColor(red: v, green: CGFloat(y % 255) / 255, blue: 1 - v, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 6, height: 6))
            }
        }
        guard let image = context.makeImage() else { throw SampleError("画像を作れません") }
        return image
    }

    private func jpegImage(_ image: CGImage) throws -> CGImage {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw SampleError("JPEG を作れません")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithData(data, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw SampleError("JPEG を作れません") }
        return decoded
    }

    /// matplotlib の対数軸の図に似せた PDF（描画の命令を文字で書き、qpdf に目録を作らせる）:
    /// 破線の補助グリッド線 30 本・短い補助目盛 40 本・長い主目盛 6 本・手描き風の破線 5 本（太さが違う）・
    /// ほぼまっすぐな 200 点の折れ線・文字「Hello Plot」
    func makeLinePlot(name: String, qpdf: URL) throws -> URL {
        var content = ""
        for i in 0..<30 { content += "q\n0.5 w\n[0.8 1.32] 0 d\n50 \(100 + i * 10) m\n550 \(100 + i * 10) l\nS\nQ\n" }
        for i in 0..<40 { content += "q\n0.6 w\n1 0 0 1 \(60 + i * 12) 90 cm\n0 0 m\n0 -2 l\nB\nQ\n" }
        for i in 0..<6 { content += "q\n0.8 w\n1 0 0 1 \(60 + i * 80) 90 cm\n0 0 m\n0 -3.5 l\nB\nQ\n" }
        for i in 0..<5 { content += "q\n1 w\n[3 3] 0 d\n50 \(450 + i * 10) m\n550 \(450 + i * 10) l\nS\nQ\n" }
        content += "q\n1 w\n100 300 m\n"
        for i in 1..<200 {
            let wobble = i % 2 == 0 ? 0.004 : -0.004
            content += String(format: "%.3f %.3f l\n", 100 + Double(i) * 2, 300 + Double(i) + wobble)
        }
        content += "S\nQ\nBT /F1 12 Tf 100 700 Td (Hello Plot) Tj ET\n"

        let raw = directory.appendingPathComponent("raw-" + name)
        let text = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj
        4 0 obj << /Length \(content.utf8.count) >> stream
        \(content)endstream endobj
        5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
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
        guard [0, 3].contains(process.terminationStatus) else { throw SampleError("図の PDF を作れません") }
        return url
    }
}

