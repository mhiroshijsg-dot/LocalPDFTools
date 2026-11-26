import CoreGraphics
import Foundation
import PDFEngine
import Testing

@Suite("重い図を画像にする")
struct FigureRasterizationTests {
    let workspace: TestWorkspace
    let factory: FigureSampleFactory
    let paper: URL

    init() throws {
        workspace = try TestWorkspace()
        factory = FigureSampleFactory(directory: workspace.directory, qpdf: workspace.qpdf.executableURL)
        paper = try factory.makePaper(name: "論文.pdf", points: 100_000)
    }

    var finder: HeavyFigureFinder { HeavyFigureFinder(runner: workspace.qpdf) }
    var compressor: PDFCompressor { PDFCompressor(runner: workspace.qpdf) }

    func settings(_ report: FigureReport, dpi: Int = 200) -> CompressionSettings {
        CompressionSettings(structural: false,
                            figures: FigureRasterization(isEnabled: true, selected: Set(report.heavyFigures.map(\.id)), dpi: dpi))
    }

    /// 圧縮して out に書き、数（画像にした図の数など）を返す
    func compress(_ input: URL, _ settings: CompressionSettings, to out: URL) async throws -> CompressionResult {
        try await compressor.compressFile(input, settings: settings, into: out)
    }

    func bodyText(_ url: URL) throws -> String {
        try workspace.document(url).string ?? ""
    }

    @Test("ページに置かれた重い図が見つかり、命令の数・ページ・置かれた大きさが分かる")
    func find() async throws {
        let report = try await finder.find(paper)
        let figure = try #require(report.heavyFigures.first)
        #expect(report.heavyFigures.count == 1)
        #expect(figure.operationCount >= 200_000)
        #expect(figure.pageNumber == 1)
        #expect(abs(figure.placedSize.width - 200) < 1)
        #expect(abs(figure.placedSize.height - 150) < 1)
        // ページ上で 200 × 150 ポイント → 200 dpi で 556 × 417 ピクセル
        let pixels = figure.pixelSize(dpi: 200)
        #expect(pixels.width == 556 && pixels.height == 417)
        #expect(figure.isEffective(dpi: 200))
        #expect(report.heavyPages.isEmpty)
    }

    @Test("点の少ない図は重い図に入らない")
    func lightFigure() async throws {
        let light = try factory.makePaper(name: "軽い図.pdf", points: 50)
        let report = try await finder.find(light)
        #expect(report.figures.count == 1)
        #expect(report.heavyFigures.isEmpty)
    }

    @Test("画像にすると小さくなり、本文の文字・ページの大きさは残り、入力は変わらない")
    func flatten() async throws {
        let report = try await finder.find(paper)
        let before = try workspace.sha(paper)
        let out = workspace.url("画像化.pdf")
        let result = try await compress(paper, settings(report), to: out)
        #expect(FileSize.of(out)! < FileSize.of(paper)! / 2)
        #expect(result.flattenedFigures == 1)
        #expect(try workspace.sha(paper) == before)
        #expect(try workspace.pageWidths(out) == [612])
        #expect(try bodyText(out).contains("Body text stays selectable"))
        // 図の中の文字（"Scatter"）は画像になったので、もう文字としては取り出せない
        #expect(try bodyText(paper).contains("Scatter"))
        #expect(!(try bodyText(out).contains("Scatter")))
        // 画像にした図の中身は「画像を 1 枚置く」命令だけ
        let after = try await finder.find(out)
        #expect(after.heavyFigures.isEmpty)
        #expect(after.figures.count == 1)
        #expect((after.figures.first?.operationCount ?? 99) == 0)
        // 一時ファイルが残らない
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: workspace.directory.path)
            .filter { $0.hasPrefix("compress-") }
        #expect(leftovers.isEmpty)
        if let figure = report.heavyFigures.first {
            print("図の画像化: \(FileSize.of(paper)!) → \(FileSize.of(out)!) バイト・図 \(figure.byteCount) バイト・目安 \(figure.estimatedBytes(dpi: 200)) バイト")
        }
    }

    @Test("画像にした図は同じ位置・同じ大きさで描かれる（ページを描いた絵が元とほぼ同じ）")
    func samePlace() async throws {
        let report = try await finder.find(paper)
        let out = workspace.url("画像化-位置.pdf")
        _ = try await compress(paper, settings(report, dpi: 300), to: out)
        let original = try render(paper)
        let flattened = try render(out)
        // 図の外側（本文の上の余白）と図の中の平均の明るさが、元とほぼ同じ
        #expect(abs(original.figure - flattened.figure) < 0.03)
        #expect(abs(original.outside - flattened.outside) < 0.001)
    }

    @Test("同じ図が 2 か所に置かれていても、両方が画像になる")
    func twoPlacements() async throws {
        let twice = try factory.makePaper(name: "2 か所.pdf", points: 100_000, placements: 2)
        let report = try await finder.find(twice)
        #expect(!report.heavyFigures.isEmpty)
        let out = workspace.url("2 か所-画像化.pdf")
        _ = try await compress(twice, settings(report), to: out)
        let after = try await finder.find(out)
        #expect(after.heavyFigures.isEmpty)
        #expect(after.figures.allSatisfy { $0.operationCount == 0 })
        #expect(!(try bodyText(out).contains("Scatter")))
    }

    @Test("解除・結合で部品の番号が変わっても、選んだ図は同じ図として見つかる")
    func idSurvivesMerge() async throws {
        let report = try await finder.find(paper)
        let merged = workspace.url("結合.pdf")
        _ = try await PDFMerger(runner: workspace.qpdf).merge([workspace.fileA, paper], to: merged)
        let after = try await finder.find(merged)
        #expect(Set(after.heavyFigures.map(\.id)) == Set(report.heavyFigures.map(\.id)))
        #expect(after.heavyFigures.first?.pageNumber == 3)
        let out = workspace.url("結合-画像化.pdf")
        #expect(try await compress(merged, settings(report), to: out).flattenedFigures == 1)
        #expect(try workspace.pageWidths(out) == [300, 300, 612])
    }

    @Test("線を減らすと一緒に選んでも、画像にした図はそのまま画像になる")
    func withThinning() async throws {
        let report = try await finder.find(paper)
        var both = settings(report)
        both.vector = VectorThinning(removeMinorGrid: true, removeMinorTicks: true, simplifyCurves: true)
        let out = workspace.url("画像化-線.pdf")
        #expect(try await compress(paper, both, to: out).flattenedFigures == 1)
        #expect(try bodyText(out).contains("Body text stays selectable"))
    }

    @Test("縮小表示を作れる")
    func thumbnails() async throws {
        let report = try await finder.find(paper)
        let images = try await FigureRasterizer(runner: workspace.qpdf)
            .thumbnails(paper, figures: report.heavyFigures, maxPixels: 120)
        let figure = try #require(report.heavyFigures.first)
        let image = try #require(images[figure.id])
        #expect(max(image.width, image.height) == 120)
    }

    @Test("制限付き（暗号化あり）の PDF でも、暗号化を保ったまま画像にできる")
    func restricted() async throws {
        let locked = try workspace.factory.encrypt(paper, name: "論文-制限付き.pdf", userPassword: "",
                                                   qpdf: workspace.qpdf.executableURL)
        let report = try await finder.find(locked)
        #expect(report.heavyFigures.count == 1)
        let out = workspace.url("制限付き-画像化.pdf")
        #expect(try await compress(locked, settings(report), to: out).flattenedFigures == 1)
        #expect(try PDFInspector().inspect(out).isEncrypted)
    }

    /// ページを 72 dpi の灰色の絵に描き、図のあたりと図の外側（上の余白）の平均の明るさを返す
    private func render(_ url: URL) throws -> (figure: Double, outside: Double) {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1),
              let context = CGContext(data: nil, width: 612, height: 792, bitsPerComponent: 8, bytesPerRow: 612,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw SampleError("描けません") }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
        context.drawPDFPage(page)
        guard let data = context.data else { throw SampleError("描けません") }
        let pixels = data.bindMemory(to: UInt8.self, capacity: 612 * 792)
        func mean(_ rect: CGRect) -> Double {
            var sum = 0, count = 0
            // ビットマップの行は下から上（Core Graphics の座標と同じ向きで、メモリは上の行から）
            for y in Int(rect.minY)..<Int(rect.maxY) {
                let row = 791 - y
                for x in Int(rect.minX)..<Int(rect.maxX) {
                    sum += Int(pixels[row * 612 + x])
                    count += 1
                }
            }
            return Double(sum) / Double(max(count, 1)) / 255
        }
        return (mean(CGRect(x: 100, y: 420, width: 200, height: 150)), mean(CGRect(x: 320, y: 420, width: 200, height: 150)))
    }
}
