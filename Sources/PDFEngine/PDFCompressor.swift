import Foundation

/// PDF を小さくする。
/// - 画像: qpdf で画像のデータを取り出し → Mac 標準の画像処理で縮小・再圧縮 → qpdf で差し戻す（`--update-from-json`）
/// - 構造の圧縮: qpdf で小さな部品をまとめて圧縮し、データの圧縮をし直す（見た目は一切変わらない）
/// - 重い図を画像にする（選んだときだけ）: 図の中身を、同じ枠いっぱいに置いた 1 枚の画像に置き換える（PDFFigureFlattener）
/// 文字・フォントには触れない。白黒スキャン（CCITT・JBIG2）なども触らない（PDFImageInfo.unsupportedReason）。
/// MEMO(2026-11-24・by claude): 計画 §3。gs を使わないのは、配布しやすさ（AGPL）と、決めたとおりにしか変わらないため。
public struct PDFCompressor {
    /// 進み具合（0〜1）を知らせる
    public typealias Progress = @Sendable (Double) -> Void

    let runner: QPDFRunner
    let writer = OutputWriter()

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// 圧縮して保存先へ置く（主に検査用。画面からは PDFPipeline を通す）
    public func compress(_ input: URL, settings: CompressionSettings, to destination: URL) async throws -> OperationOutcome {
        try await writer.write(to: destination, inputs: [input]) { temporary in
            try await compressFile(input, settings: settings, into: temporary).warnings
        }
    }

    /// 一時ファイル output に圧縮した PDF を作る。画像の作業用のファイルは output と同じフォルダに作って消す。
    /// 中止（Task のキャンセル）されたら CancellationError を投げる。
    public func compressFile(_ input: URL, settings: CompressionSettings, into output: URL,
                             progress: Progress? = nil) async throws -> CompressionResult {
        let work = output.deletingLastPathComponent()
            .appendingPathComponent("compress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        var result = CompressionResult()
        var updates: [String: Any] = [:]
        var maxObjectID = 0
        var table: QPDFObjectTable?
        if settings.touchesImages || settings.vector.isActive || settings.figures.isActive {
            let loaded = try await QPDFObjectTable.load(input, runner: runner)
            table = loaded
            maxObjectID = loaded.objects.keys.compactMap { Int($0.split(separator: " ").first ?? "") }.max() ?? 0
        }
        // 順番: 図を画像にする → 線を減らす（画像にした図は除く）→ 画像の縮小・画質（画像にした図の中の画像は除く）
        var figureUpdates: [String: Any] = [:]
        var replacedRefs = Set<String>()
        if let table, settings.figures.isActive {
            let flattened = try await PDFFigureFlattener(runner: runner)
                .apply(input, table: table, settings: settings.figures, maxObjectID: maxObjectID, workDirectory: work)
            figureUpdates = flattened.updates
            replacedRefs = flattened.replacedRefs
            result.flattenedFigures = flattened.flattened
            result.keptFigures = flattened.kept
        }
        if let table, settings.vector.isActive {
            let thinned = try await PDFVectorThinner(runner: runner)
                .apply(input, table: table, thinning: settings.vector, workDirectory: work, skipping: replacedRefs)
            updates.merge(thinned.updates) { _, new in new }
            result.vector = thinned.report
        }
        if let table, settings.touchesImages {
            let report = try PDFContentAnalyzer(runner: runner).analyze(input, table: table)
            let targets = report.images.filter { image in
                !replacedRefs.contains(image.ref) && image.isSupported && (image.resampledSize(targetDPI: settings.targetDPI) != nil
                                      || (image.encoding == .jpeg && settings.jpegQuality != nil))
            }
            for (index, image) in targets.enumerated() {
                try Task.checkCancellation()
                progress?(Double(index) / Double(max(targets.count, 1)))
                let data = try await streamData(of: image, in: input)
                guard let replacement = ImageRecompressor().recompress(image, data: data, settings: settings),
                      var dictionary = table.streamDictionary(image.ref) else {
                    result.keptImages += 1
                    continue
                }
                let file = work.appendingPathComponent("image-\(index).bin")
                try replacement.data.write(to: file)
                dictionary["/Width"] = replacement.width
                dictionary["/Height"] = replacement.height
                dictionary["/BitsPerComponent"] = 8
                dictionary["/Filter"] = replacement.filter
                dictionary["/DecodeParms"] = nil
                dictionary["/Length"] = nil
                updates["obj:" + image.ref] = ["stream": ["dict": dictionary, "datafile": file.path]]
                if replacement.wasResampled { result.resampledImages += 1 } else { result.requalifiedImages += 1 }
            }
        }
        // 画像にした図の書き換えを最後に重ねる（同じ部品への指定があれば、こちらを優先）
        updates.merge(figureUpdates) { _, new in new }
        try Task.checkCancellation()
        progress?(1)

        var arguments = [input.path, output.path]
        if !updates.isEmpty {
            let header: [String: Any] = ["jsonversion": 2, "pushedinheritedpageresources": false,
                                         "calledgetallpages": false, "maxobjectid": maxObjectID]
            let json = work.appendingPathComponent("update.json")
            try JSONSerialization.data(withJSONObject: ["qpdf": [header, updates]]).write(to: json)
            arguments.append("--update-from-json=" + json.path)
        }
        if settings.structural {
            arguments += ["--object-streams=generate", "--recompress-flate", "--compression-level=9"]
        }
        result.warnings = try await runner.runChecked(arguments).warningLines
        return result
    }

    /// 図の線を減らすと、どれだけ減るかを数える（書き換えない）
    public func previewThinning(_ url: URL) async throws -> VectorThinningReport {
        let table = try await QPDFObjectTable.load(url, runner: runner)
        return try await PDFVectorThinner(runner: runner).preview(url, table: table)
    }

    /// JPEG はそのままの形で、可逆の圧縮（Flate）は圧縮を解いた画素で取り出す
    private func streamData(of image: PDFImageInfo, in url: URL) async throws -> Data {
        let parts = image.ref.split(separator: " ")
        let id = parts.count >= 2 ? "\(parts[0]),\(parts[1])" : String(parts.first ?? "")
        let mode = image.encoding == .jpeg ? "--raw-stream-data" : "--filtered-stream-data"
        return try await runner.runChecked(["--show-object=" + id, mode, url.path]).standardOutputData
    }
}
