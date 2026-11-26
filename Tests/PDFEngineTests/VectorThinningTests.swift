import Foundation
@testable import PDFEngine
import PDFKit
import Testing

@Suite("図の線を減らす（make_compact_pdf の移植）")
struct VectorThinningTests {
    let workspace: TestWorkspace
    let plot: URL
    init() throws {
        workspace = try TestWorkspace()
        plot = try workspace.factory.makeLinePlot(name: "図.pdf", qpdf: workspace.qpdf.executableURL)
    }

    var compressor: PDFCompressor { PDFCompressor(runner: workspace.qpdf) }

    func text(_ url: URL) throws -> String {
        try workspace.document(url).page(at: 0)?.string ?? ""
    }

    @Test("実行前に数える: 補助グリッド線 30 本・補助目盛 40 本。主目盛と、繰り返しの少ない破線は数えない")
    func preview() async throws {
        let report = try await compressor.previewThinning(plot)
        #expect(report.gridLines == 30)
        #expect(report.tickMarks == 40)
        #expect(report.pointsBefore == 200)
        #expect(report.pointsAfter == 2)
        #expect(report.gridBytes > 0 && report.tickBytes > 0 && report.curveBytes > 0)
    }

    @Test("①②③をすべて行う: 消した数が合い、文字は残り、もう一度数えると何も残っていない・入力は変わらない")
    func applyAll() async throws {
        let before = try workspace.sha(plot)
        let out = workspace.url("図-全部.pdf")
        let settings = CompressionSettings(vector: VectorThinning(removeMinorGrid: true, removeMinorTicks: true, simplifyCurves: true))
        let outcome = try await compressor.compress(plot, settings: settings, to: out)
        #expect(outcome.outputBytes < outcome.inputBytes)
        #expect(try text(out).contains("Hello Plot"))
        let after = try await compressor.previewThinning(out)
        #expect(after.gridLines == 0)
        #expect(after.tickMarks == 0)
        #expect(after.pointsBefore == 0)
        #expect(try workspace.sha(plot) == before)
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("グリッド線だけ: 目盛と曲線はそのまま")
    func gridOnly() async throws {
        let out = workspace.url("図-グリッド.pdf")
        _ = try await compressor.compress(plot, settings: CompressionSettings(vector: VectorThinning(removeMinorGrid: true)), to: out)
        let after = try await compressor.previewThinning(out)
        #expect(after.gridLines == 0)
        #expect(after.tickMarks == 40)
        #expect(after.pointsBefore == 200)
    }

    @Test("すべてオフなら、描画の命令は変わらない")
    func offKeepsContent() async throws {
        let out = workspace.url("図-オフ.pdf")
        _ = try await compressor.compress(plot, settings: CompressionSettings(), to: out)
        // 数だけ比べる（大きさの目安は、構造の圧縮で命令が圧縮されるので変わる）
        let after = try await compressor.previewThinning(out)
        let before = try await compressor.previewThinning(plot)
        let afterCounts: [Int] = [after.gridLines, after.tickMarks, after.pointsBefore, after.pointsAfter]
        let beforeCounts: [Int] = [before.gridLines, before.tickMarks, before.pointsBefore, before.pointsAfter]
        #expect(afterCounts == beforeCounts)
    }

    @Test("曲線の間引きは、元の線から 0.1 ポイントより離れた点を残す")
    func toleranceKeepsCorners() {
        // まっすぐな線の途中に 1 ポイントの山が 1 つ
        var points = (0..<20).map { (Double($0), 0.0) }
        points[10].1 = 1
        let kept = ContentStreamThinner.douglasPeucker(points, tolerance: VectorThinning.tolerance)
        #expect(kept.contains(10))
        #expect(kept.first == 0 && kept.last == 19)
    }
}
