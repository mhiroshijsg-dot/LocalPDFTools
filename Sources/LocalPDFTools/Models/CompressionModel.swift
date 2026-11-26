import Foundation
import Observation
import PDFEngine

/// 圧縮のカードの状態: やり方の選択・分析・目安・試算
@MainActor
@Observable
final class CompressionModel {
    var settings = CompressionSettings() {
        didSet { if settings != oldValue { invalidateTrial() } }
    }
    private(set) var isAnalyzing = false
    private(set) var isCountingLines = false
    /// 試算の結果（ファイルごとに、実際に圧縮した大きさ）。設定やファイルを変えたら消す
    private(set) var trialSizes: [WorkFile.ID: Int64]?
    /// 試算の進み具合（0〜1）。試算していなければ nil
    private(set) var trialProgress: Double?
    private(set) var trialError: String?
    private var trialTask: Task<Void, Never>?

    // MARK: 分析

    /// まだ分析していないファイルを分析する（中身の一覧を読むだけ。画像は変換しない）
    func analyze(_ files: [WorkFile]) async {
        let targets = files.filter { $0.contentReport == nil && $0.analysisError == nil && !$0.isLocked }
        guard !targets.isEmpty, !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let analyzer = PDFContentAnalyzer(runner: try QPDFRunner.locate())
            for file in targets {
                do {
                    file.contentReport = try await analyzer.analyze(file.url)
                } catch {
                    file.analysisError = error.localizedDescription
                }
            }
        } catch {
            targets.forEach { $0.analysisError = error.localizedDescription }
        }
    }

    /// ファイル 1 つの圧縮後の大きさ: 試算があれば試算、無ければ目安（分析できていなければ nil）
    func expectedBytes(_ file: WorkFile) -> (bytes: Int64, isTrial: Bool)? {
        if let trial = trialSizes?[file.id] { return (trial, true) }
        guard let report = file.contentReport else { return nil }
        let lines = settings.vector.isActive ? (file.thinningReport?.savedBytes(settings.vector) ?? 0) : 0
        return (max(0, report.estimatedBytes(settings) - lines), false)
    }

    /// 図の線を減らすと減る数を、まだ数えていないファイルについて数える（描画の命令を読むだけで、書き換えない）
    func countLines(_ files: [WorkFile]) async {
        let targets = files.filter { $0.thinningReport == nil && !$0.isLocked }
        guard !targets.isEmpty, !isCountingLines else { return }
        isCountingLines = true
        defer { isCountingLines = false }
        guard let runner = try? QPDFRunner.locate() else { return }
        for file in targets {
            file.thinningReport = try? await PDFCompressor(runner: runner).previewThinning(file.url)
        }
    }

    // MARK: 試算

    /// 入れた PDF を実際に圧縮して（一時フォルダに作ってすぐ消す）、大きさを測る。
    /// MEMO(2026-11-26・by claude): 計画 §4.2 では「画像だけ変換して測る」だったが、PDF 全体を一時的に作って測る形にした。
    /// 手間はほぼ同じ（時間のほとんどは画像の変換）で、構造の圧縮の効き目まで含めた正確な数字になるため。
    func startTrial(_ files: [WorkFile]) {
        trialTask?.cancel()
        let targets = files.filter { !$0.isLocked }.map { ($0.id, $0.url) }
        let settings = settings
        trialSizes = nil
        trialError = nil
        trialProgress = 0
        trialTask = Task {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LocalPDFTools-trial-\(UUID().uuidString)", isDirectory: true)
            defer {
                try? FileManager.default.removeItem(at: directory)
                trialProgress = nil
            }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let compressor = PDFCompressor(runner: try QPDFRunner.locate())
                var sizes: [WorkFile.ID: Int64] = [:]
                for (index, (id, url)) in targets.enumerated() {
                    let output = directory.appendingPathComponent("trial-\(index).pdf")
                    let count = Double(targets.count)
                    _ = try await compressor.compressFile(url, settings: settings, into: output) { fraction in
                        Task { @MainActor in self.trialProgress = (Double(index) + fraction) / count }
                    }
                    sizes[id] = FileSize.of(output) ?? 0
                    try? FileManager.default.removeItem(at: output)
                }
                trialSizes = sizes
            } catch is CancellationError {
                // 中止した: 何も出さない
            } catch {
                trialError = error.localizedDescription
            }
        }
    }

    func cancelTrial() {
        trialTask?.cancel()
        trialTask = nil
    }

    /// 設定やファイルが変わったら、試算の結果は古いので消す
    func invalidateTrial() {
        cancelTrial()
        trialSizes = nil
        trialError = nil
        trialProgress = nil
    }
}
