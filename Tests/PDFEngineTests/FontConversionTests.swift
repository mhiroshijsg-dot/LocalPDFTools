import CoreGraphics
import Foundation
import PDFEngine
import Testing

/// 圧縮でいつも行う「Type1 フォントを CFF に作り直す」
@Suite("フォントの作り直し（Type1 → CFF）")
struct FontConversionTests {
    let workspace: TestWorkspace
    let factory: Type1FontFactory
    init() throws {
        workspace = try TestWorkspace()
        factory = Type1FontFactory(directory: workspace.directory, qpdf: workspace.qpdf.executableURL)
    }

    var compressor: PDFCompressor { PDFCompressor(runner: workspace.qpdf) }

    /// フォントの説明の /FontFile と /FontFile3 の数と、/FontFile3 の種類
    func fontFiles(_ url: URL) async throws -> (type1: Int, cff: [String]) {
        let output = try await workspace.qpdf.run(["--json", "--json-key=qpdf", "--json-stream-data=none", url.path])
        let root = try #require(try JSONSerialization.jsonObject(with: output.standardOutputData) as? [String: Any])
        let entries = try #require((root["qpdf"] as? [Any])?[1] as? [String: Any])
        var type1 = 0
        var cff: [String] = []
        for (_, object) in entries {
            guard let dictionary = (object as? [String: Any])?["value"] as? [String: Any],
                  (dictionary["/Type"] as? String) == "/FontDescriptor" else { continue }
            if dictionary["/FontFile"] != nil { type1 += 1 }
            if let ref = dictionary["/FontFile3"] as? String,
               let stream = (entries["obj:" + ref] as? [String: Any])?["stream"] as? [String: Any],
               let subtype = (stream["dict"] as? [String: Any])?["/Subtype"] as? String {
                cff.append(subtype)
            }
        }
        return (type1, cff)
    }

    /// ページを灰色の絵にする（1 ポイント = 2 画素）
    func render(_ url: URL) throws -> [UInt8] {
        let document = try #require(CGPDFDocument(url as CFURL))
        let page = try #require(document.page(at: 1))
        let context = try #require(CGContext(data: nil, width: 1200, height: 1600, bitsPerComponent: 8, bytesPerRow: 1200,
                                             space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
        context.scaleBy(x: 2, y: 2)
        context.drawPDFPage(page)
        let data = try #require(context.data)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: 1200 * 1600))
    }

    @Test("Type1 のフォントは CFF になり、元の Type1 は無くなる・小さくなる・壊れていない")
    func converts() async throws {
        let input = try factory.makePDF(name: "Type1.pdf")
        #expect(try await fontFiles(input).type1 == 1)
        let out = workspace.url("CFF.pdf")
        let result = try await compressor.compressFile(input, settings: CompressionSettings(), into: out)
        #expect(result.convertedFonts == 1)
        let files = try await fontFiles(out)
        #expect(files.type1 == 0)
        #expect(files.cff == ["/Type1C"])
        #expect(FileSize.of(out)! < FileSize.of(input)!)
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("見た目: 作り直す前と後で、描いた結果が同じ（flex・アクセント付きの字・端数の座標・2 つの文字の割り当てを含む）")
    func looksSame() async throws {
        let input = try factory.makePDF(name: "見た目-Type1.pdf")
        let out = workspace.url("見た目-CFF.pdf")
        _ = try await compressor.compressFile(input, settings: CompressionSettings(), into: out)
        let before = try render(input)
        let after = try render(out)
        // 元のフォントがちゃんと描かれていること（両方とも白紙で「同じ」にならないように）
        let ink = before.filter { $0 < 128 }.count
        #expect(ink > 20_000, "黒い画素 \(ink)")
        // 検査用のフォントの B は塗りつぶした四角（ほかの書体で代わりに描かれると、ここに白い所が出る）。
        // 2 行目（F2・60 ポイント・左下 30, 500）の 2 文字目: x 69〜93・y 500〜536 ポイント。その内側が全部黒いこと
        var whiteInsideB = 0
        for y in 505...530 {
            for x in 75...87 where before[(1600 - 1 - y * 2) * 1200 + x * 2] > 80 { whiteInsideB += 1 }
        }
        #expect(whiteInsideB == 0, "B の中の白い画素 \(whiteInsideB)")
        let differing = zip(before, after).filter { abs(Int($0) - Int($1)) > 32 }.count
        #expect(differing == 0, "色の差が 32 を超える画素 \(differing)")
    }

    @Test("作り直せないフォント（知らない命令がある）は、元の Type1 のまま残す")
    func keepsUnknown() async throws {
        let input = try factory.makePDF(name: "壊れた-Type1.pdf", broken: true)
        let out = workspace.url("壊れた-出力.pdf")
        let result = try await compressor.compressFile(input, settings: CompressionSettings(), into: out)
        #expect(result.convertedFonts == 0)
        let files = try await fontFiles(out)
        #expect(files.type1 == 1 && files.cff.isEmpty)
    }
}
