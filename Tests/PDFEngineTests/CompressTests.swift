import Foundation
import PDFEngine
import Testing

@Suite("圧縮")
struct CompressTests {
    let workspace: TestWorkspace
    let images: URL
    init() throws {
        workspace = try TestWorkspace()
        images = try workspace.factory.makeWithImages(name: "画像入り.pdf")
    }

    var analyzer: PDFContentAnalyzer { PDFContentAnalyzer(runner: workspace.qpdf) }
    var compressor: PDFCompressor { PDFCompressor(runner: workspace.qpdf) }

    func jpeg(_ report: PDFContentReport) throws -> PDFImageInfo {
        try #require(report.images.first { $0.encoding == .jpeg })
    }

    func flate(_ report: PDFContentReport) throws -> PDFImageInfo {
        try #require(report.images.first { $0.encoding == .flate })
    }

    // MARK: 分析

    @Test("画像の形式・ピクセル数・ページ上の解像度が分かる")
    func analyze() async throws {
        let report = try await analyzer.analyze(images)
        #expect(report.images.count == 2)
        let photo = try jpeg(report)
        #expect(photo.pixelWidth == 1275 && photo.pixelHeight == 900)
        #expect(photo.components == 3)
        #expect(abs((photo.effectivePPI ?? 0) - 300) < 1)
        #expect(photo.isSupported)
        let gray = try flate(report)
        #expect(gray.components == 1)
        #expect(abs((gray.effectivePPI ?? 0) - 150) < 1)
        #expect(report.imageBytes > 0 && report.imageBytes < report.totalBytes)
        #expect(report.totalBytes == FileSize.of(images))
    }

    @Test("縮めて図として置いたページの中の画像は、ページ上でより細かいと分かる")
    func nestedForm() async throws {
        let nested = try workspace.factory.makeWithNestedPage(name: "入れ子.pdf", source: images, scale: 0.5)
        let photo = try jpeg(try await analyzer.analyze(nested))
        #expect(abs((photo.effectivePPI ?? 0) - 600) < 2)
    }

    @Test("解像度を下げる画像の数と、目安の大きさ")
    func estimate() async throws {
        let report = try await analyzer.analyze(images)
        #expect(report.resampledCount(targetDPI: 200) == 1)
        #expect(report.resampledCount(targetDPI: 100) == 2)
        #expect(report.resampledCount(targetDPI: nil) == 0)
        #expect(report.estimatedBytes(CompressionSettings()) == report.totalBytes)
        #expect(report.estimatedBytes(CompressionSettings(targetDPI: 150)) < report.totalBytes / 2)
    }

    // MARK: 圧縮

    @Test("150 dpi: 300 ppi の写真だけ半分の大きさにし、150 ppi の画像には触らない・入力は変わらない")
    func downsample150() async throws {
        let before = try workspace.sha(images)
        let out = workspace.url("150dpi.pdf")
        let outcome = try await compressor.compress(images, settings: CompressionSettings(targetDPI: 150), to: out)
        let report = try await analyzer.analyze(out)
        let photo = try jpeg(report)
        #expect(photo.pixelWidth == 638 && photo.pixelHeight == 450)
        #expect(abs((photo.effectivePPI ?? 0) - 150) < 1)
        let gray = try flate(report)
        #expect(gray.pixelWidth == 600 && gray.pixelHeight == 400)
        #expect(outcome.outputBytes < outcome.inputBytes / 2)
        #expect(try workspace.sha(images) == before)
        #expect(try workspace.document(out).pageCount == 1)
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("72 dpi: 可逆の画像も縮める（形式は可逆のまま）")
    func downsample72() async throws {
        let out = workspace.url("72dpi.pdf")
        _ = try await compressor.compress(images, settings: CompressionSettings(targetDPI: 72), to: out)
        let report = try await analyzer.analyze(out)
        let gray = try flate(report)
        #expect(gray.pixelWidth == 288 && gray.pixelHeight == 192)
        #expect(gray.components == 1)
        #expect(try jpeg(report).pixelWidth == 306)
    }

    @Test("画質だけ下げる: 大きさは同じで、JPEG が小さくなる")
    func qualityOnly() async throws {
        let original = try jpeg(try await analyzer.analyze(images))
        let out = workspace.url("画質.pdf")
        _ = try await compressor.compress(images, settings: CompressionSettings(jpegQuality: .lowest), to: out)
        let photo = try jpeg(try await analyzer.analyze(out))
        #expect(photo.pixelWidth == 1275)
        #expect(photo.byteCount < original.byteCount)
    }

    @Test("構造の圧縮だけ: 画像はそのまま・壊れていない")
    func structuralOnly() async throws {
        let out = workspace.url("構造.pdf")
        _ = try await compressor.compress(images, settings: CompressionSettings(), to: out)
        let report = try await analyzer.analyze(out)
        #expect(try jpeg(report).pixelWidth == 1275)
        #expect(try flate(report).pixelWidth == 600)
        let check = try await workspace.qpdf.run(["--check", out.path])
        #expect(check.exitCode == 0)
    }

    @Test("制限付きの PDF を解除せずに圧縮すると、暗号化はそのまま残る")
    func keepsEncryption() async throws {
        let restricted = try workspace.factory.encrypt(images, name: "画像-制限.pdf", userPassword: "",
                                                       qpdf: workspace.qpdf.executableURL)
        let out = workspace.url("画像-制限-圧縮.pdf")
        _ = try await compressor.compress(restricted, settings: CompressionSettings(targetDPI: 150), to: out)
        let status = try await PDFEncryptionInspector(runner: workspace.qpdf).inspect(out).status
        #expect(status == .restricted)
        #expect(try jpeg(try await analyzer.analyze(out)).pixelWidth == 638)
    }

    @Test("続けて処理: 解除 → 結合 → 圧縮。結果は暗号化なし・ページ数どおり・画像が縮む")
    func pipelineWithCompress() async throws {
        let restricted = try workspace.factory.encrypt(images, name: "画像-制限.pdf", userPassword: "",
                                                       qpdf: workspace.qpdf.executableURL)
        let files = [PipelineFile(url: restricted, encryption: .restricted, rotation: RotationPlan(pageCount: 1)),
                     PipelineFile(url: workspace.fileB, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 3))]
        let out = workspace.url("解除-結合-圧縮.pdf")
        let outcome = try await PDFPipeline(runner: workspace.qpdf)
            .run(files, steps: [.decrypt, .merge, .compress], compression: CompressionSettings(targetDPI: 150),
                 to: out) { _, _ in nil }
        #expect(try workspace.document(out).pageCount == 4)
        #expect(try await PDFEncryptionInspector(runner: workspace.qpdf).inspect(out).status == .notEncrypted)
        #expect(outcome.compression?.resampledImages == 1)
        #expect(try jpeg(try await analyzer.analyze(out)).pixelWidth == 638)
    }

    @Test("中止すると止まり、保存先は作られない")
    func cancel() async throws {
        let out = workspace.url("中止.pdf")
        let task = Task {
            try await compressor.compress(images, settings: CompressionSettings(targetDPI: 72), to: out)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }
}
