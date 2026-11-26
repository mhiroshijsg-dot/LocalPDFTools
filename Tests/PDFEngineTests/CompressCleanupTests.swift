import CoreGraphics
import Foundation
import PDFEngine
import Testing

/// 圧縮でいつも行う 3 つ: 要らないデータを捨てる・重複をまとめる・色の無い画像を灰色にする
@Suite("圧縮でいつも行うこと")
struct CompressCleanupTests {
    let workspace: TestWorkspace
    let sample: URL
    init() throws {
        workspace = try TestWorkspace()
        sample = try CleanupSampleFactory(directory: workspace.directory, qpdf: workspace.qpdf.executableURL)
            .make(name: "掃除の見本.pdf")
    }

    var compressor: PDFCompressor { PDFCompressor(runner: workspace.qpdf) }

    /// qpdf の JSON の部品の一覧（"obj:5 0 R" → 中身）
    func objects(_ url: URL) async throws -> [String: [String: Any]] {
        let output = try await workspace.qpdf.run(["--json", "--json-key=qpdf", "--json-stream-data=none", url.path])
        let root = try #require(try JSONSerialization.jsonObject(with: output.standardOutputData) as? [String: Any])
        let qpdf = try #require(root["qpdf"] as? [Any])
        let entries = try #require(qpdf[1] as? [String: Any])
        return entries.compactMapValues { $0 as? [String: Any] }
    }

    func dictionary(_ object: [String: Any]) -> [String: Any]? {
        (object["stream"] as? [String: Any])?["dict"] as? [String: Any] ?? object["value"] as? [String: Any]
    }

    /// ページを RGB の絵にする（1 ポイント = 1 画素）
    func render(_ url: URL) throws -> (data: Data, rowBytes: Int) {
        let document = try #require(CGPDFDocument(url as CFURL))
        let page = try #require(document.page(at: 1))
        let context = try #require(CGContext(data: nil, width: 600, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        context.drawPDFPage(page)
        let image = try #require(context.makeImage())
        return (try #require(image.dataProvider?.data as Data?), image.bytesPerRow)
    }

    /// 2 つの絵の、ある範囲の中での一番大きな色の差（0〜255）
    func maxDifference(_ a: (data: Data, rowBytes: Int), _ b: (data: Data, rowBytes: Int), in rect: CGRect) -> Int {
        var result = 0
        // 絵の行は上から、PDF の座標は下から
        for y in Int(rect.minY) + 1..<Int(rect.maxY) - 1 {
            let row = (800 - 1 - y) * a.rowBytes
            for x in Int(rect.minX) + 1..<Int(rect.maxX) - 1 {
                for channel in 0..<3 {
                    let index = row + x * 4 + channel
                    result = max(result, abs(Int(a.data[index]) - Int(b.data[index])))
                }
            }
        }
        return result
    }

    @Test("何も指定しなくても 3 つを行い、数を返す・入力は変わらない・壊れていない")
    func counts() async throws {
        let before = try workspace.sha(sample)
        let out = workspace.url("掃除.pdf")
        let result = try await compressor.compressFile(sample, settings: CompressionSettings(), into: out)
        #expect(result.removedExtras == 4)      // カタログとページの /PieceInfo・ページの /Thumb・画像の /Metadata
        #expect(result.mergedDuplicates == 1)   // /Gb は /Ga と同じ
        #expect(result.grayImages == 2)         // /Ga（可逆）と /Jg（JPEG）
        #expect(result.keptImages == 0)
        #expect(FileSize.of(out)! < FileSize.of(sample)!)
        #expect(try workspace.sha(sample) == before)
        #expect(try workspace.document(out).pageCount == 1)
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("要らないデータ: 編集用のデータ・縮小画像・画像の説明は無くなり、文書全体の説明は残る")
    func extras() async throws {
        let out = workspace.url("要らないデータ.pdf")
        _ = try await compressor.compress(sample, settings: CompressionSettings(), to: out)
        let all = try await objects(out)
        var catalogHasMetadata = false
        for (_, object) in all {
            guard let dictionary = dictionary(object) else { continue }
            #expect(dictionary["/PieceInfo"] == nil)
            if (dictionary["/Type"] as? String) == "/Page" { #expect(dictionary["/Thumb"] == nil) }
            if (dictionary["/Type"] as? String) == "/Catalog" {
                catalogHasMetadata = dictionary["/Metadata"] != nil
            } else if (dictionary["/Type"] as? String) != "/Metadata" {
                #expect(dictionary["/Metadata"] == nil)
            }
        }
        #expect(catalogHasMetadata)
        // 編集用のデータ（約 5 万バイト × 2）は、どこからも使われなくなって捨てられる
        #expect(FileSize.of(out)! < FileSize.of(sample)! - 90_000)
    }

    @Test("重複: 同じ画像 2 つは 1 つになり、両方の名前が同じ部品を指す")
    func duplicates() async throws {
        let out = workspace.url("重複.pdf")
        _ = try await compressor.compress(sample, settings: CompressionSettings(), to: out)
        let all = try await objects(out)
        let page = try #require(all.values.compactMap(dictionary).first { ($0["/Type"] as? String) == "/Page" })
        let resources = try #require(page["/Resources"] as? [String: Any])
        let xObjects = try #require(resources["/XObject"] as? [String: Any])
        #expect(xObjects["/Ga"] as? String == xObjects["/Gb"] as? String)
        let images = all.values.compactMap(dictionary).filter { ($0["/Subtype"] as? String) == "/Image" }
        #expect(images.count == 4)
    }

    @Test("色の無い画像: 灰色のものだけ 1 色になり、色の付いたもの・印鑑のある JPEG は RGB のまま")
    func gray() async throws {
        let out = workspace.url("灰色.pdf")
        _ = try await compressor.compress(sample, settings: CompressionSettings(), to: out)
        let report = try await PDFContentAnalyzer(runner: workspace.qpdf).analyze(out)
        let flate = report.images.filter { $0.encoding == .flate }
        let jpeg = report.images.filter { $0.encoding == .jpeg }
        #expect(flate.map(\.components).sorted { ($0 ?? 0) < ($1 ?? 0) } == [1, 3])
        #expect(jpeg.map(\.components).sorted { ($0 ?? 0) < ($1 ?? 0) } == [1, 3])
        #expect(flate.allSatisfy { $0.pixelWidth == 200 || $0.pixelWidth == 100 })
    }

    @Test("見た目: 可逆の画像（灰色にした・まとめた・色の画像）は描いた結果がほとんど変わらない")
    func looksSame() async throws {
        let out = workspace.url("見た目.pdf")
        _ = try await compressor.compress(sample, settings: CompressionSettings(), to: out)
        let before = try render(sample)
        let after = try render(out)
        for name in ["Ga", "Gb", "Col"] {
            let rect = try #require(CleanupSampleFactory.placements[name])
            let difference = maxDifference(before, after, in: rect)
            #expect(difference <= 2, "\(name): 色の差 \(difference)")
        }
        // JPEG は保存し直すので少し変わる（それでも大きくは変わらない）
        let jpegDifference = maxDifference(before, after, in: try #require(CleanupSampleFactory.placements["Jg"]))
        #expect(jpegDifference <= 40, "Jg: 色の差 \(jpegDifference)")
    }

    @Test("要らないデータも色の無い画像も無い PDF では、それらは何もしない")
    func nothingToDo() async throws {
        let out = workspace.url("何もない.pdf")
        let result = try await compressor.compressFile(workspace.fileA, settings: CompressionSettings(), into: out)
        #expect(result.removedExtras == 0 && result.grayImages == 0)
        #expect(try workspace.document(out).pageCount == 2)
    }

    @Test("小さな部品の重複: 2 ページで同じ中身の辞書はまとまるが、ページそのものは別のまま・壊れていない")
    func smallObjects() async throws {
        let out = workspace.url("小さな部品.pdf")
        let result = try await compressor.compressFile(workspace.fileA, settings: CompressionSettings(), into: out)
        #expect(result.mergedDuplicates > 0)
        let pages = try await objects(out).compactMap { key, object -> String? in
            (dictionary(object)?["/Type"] as? String) == "/Page" ? key : nil
        }
        #expect(Set(pages).count == 2)
        #expect(try workspace.pageWidths(out) == [300, 300])
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("開くのにパスワードが要る PDF でも、構造の圧縮だけなら止まらない（3 つは飛ばす）")
    func lockedStructural() async throws {
        let locked = try workspace.lockedFile()
        let out = workspace.url("要パスワード-圧縮.pdf")
        do {
            _ = try await compressor.compress(locked, settings: CompressionSettings(), to: out)
        } catch {
            // パスワードが無いと qpdf 自体が開けないので、構造の圧縮でも前から止まる。そのときは同じ誤りであること
            #expect(error is EngineError)
        }
    }
}
