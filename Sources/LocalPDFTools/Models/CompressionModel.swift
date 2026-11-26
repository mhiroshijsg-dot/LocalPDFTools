import CoreGraphics
import Foundation
import Observation
import PDFEngine

/// 圧縮のカードの状態: やり方の選択・分析・目安・試算
@MainActor
@Observable
final class CompressionModel {
    /// MEMO(2026-11-26・by claude): 村田さんの指示で、圧縮をオンにしたときは「図の線を減らす」のすべて（補助グリッド線と補助目盛・曲線の点）にチェックが付いた状態で始める。
    /// エンジンの `VectorThinning` の既定（すべてオフ）は変えず、画面の初期値だけを変えている。①②は「見た目が変わります」の表示が出る。
    /// MEMO(2026-11-26・by claude): 品質（高・中・低）を入れてからは、最初は品質「高」の設定で始める（線を減らすも全部オンのまま）。
    var settings = CompressionPreset.initial.settings(keeping: CompressionSettings()) {
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
    /// ファイルごとの図の一覧（圧縮をオンにしたときの分析で作る）。
    /// MEMO(2026-11-26・by claude): WorkFile は段階 3 のセッションが書き換え中だったので、図の一覧はここに持つ。
    private(set) var figureReports: [WorkFile.ID: FigureReport] = [:]
    /// 図を探せなかった理由
    private(set) var figureErrors: [WorkFile.ID: String] = [:]
    /// 図の縮小表示（図の指紋 → 絵）。シートを開いたときに初めて作る
    private(set) var figureThumbnails: [String: CGImage] = [:]
    /// 縮小表示を作っているファイル
    private(set) var loadingThumbnails = Set<WorkFile.ID>()

    // MARK: 分析

    /// まだ分析していないファイルを分析する（中身の一覧を読むだけ。画像は変換しない）
    func analyze(_ files: [WorkFile]) async {
        let targets = files.filter { $0.contentReport == nil && $0.analysisError == nil && !$0.isLocked }
        guard !targets.isEmpty, !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let analyzer = PDFContentAnalyzer(runner: try QPDFRunner.locate())
            let finder = HeavyFigureFinder(runner: try QPDFRunner.locate())
            for file in targets {
                do {
                    file.contentReport = try await analyzer.analyze(file.url)
                } catch {
                    file.analysisError = error.localizedDescription
                }
                // 図を探すのも、描画の命令を読むだけ（図を描いたり画像にしたりはしない）
                do {
                    let report = try await finder.find(file.url)
                    figureReports[file.id] = report
                    // 「図を画像にする」がオンなら、新しく入れたファイルの効果のある図にもチェックを付ける
                    if settings.figures.isEnabled {
                        settings.figures.selected.formUnion(effectiveFigures(in: report).map(\.id))
                    }
                } catch {
                    figureErrors[file.id] = error.localizedDescription
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
        let figures = selectedFigures(in: file)
        let figureSaving = figures.reduce(Int64(0)) { $0 + max(0, $1.byteCount - $1.estimatedBytes(dpi: settings.figures.dpi)) }
        var lines = settings.vector.isActive ? (file.thinningReport?.savedBytes(settings.vector) ?? 0) : 0
        // 画像にする図の線は減らさないので、その分を線の目安から除く（線や点の命令の大きさの割合で按分する大まかな計算）
        let figureVector = figures.reduce(Int64(0)) { $0 + $1.vectorBytes }
        if figureVector > 0, report.otherBytes > 0 {
            lines = Int64(Double(lines) * max(0, 1 - Double(figureVector) / Double(report.otherBytes)))
        }
        return (max(0, report.estimatedBytes(settings) - lines - figureSaving), false)
    }

    // MARK: 重い図を画像にする

    /// 画像にすると小さくなる見込みのある重い図
    func effectiveFigures(in report: FigureReport) -> [HeavyFigure] {
        report.heavyFigures.filter { $0.isEffective(dpi: settings.figures.dpi) }
    }

    /// 画像にするよう選ばれている図（スイッチがオフなら無し）
    func selectedFigures(in file: WorkFile) -> [HeavyFigure] {
        guard settings.figures.isEnabled else { return [] }
        return figureReports[file.id]?.heavyFigures.filter { settings.figures.selected.contains($0.id) } ?? []
    }

    /// 入れてあるファイルの重い図（ファイルを外した後の古い一覧は数えない）
    func heavyFigures(in files: [WorkFile]) -> [(file: WorkFile, figure: HeavyFigure)] {
        files.flatMap { file in (figureReports[file.id]?.heavyFigures ?? []).map { (file, $0) } }
    }

    /// 「図を画像にする」をオンにしたら、効果のある図すべてにチェックを付ける。オフにしたらチェックを外す
    func setFiguresEnabled(_ isEnabled: Bool, files: [WorkFile]) {
        settings.figures.isEnabled = isEnabled
        settings.figures.selected = isEnabled
            ? Set(heavyFigures(in: files).map(\.figure).filter { $0.isEffective(dpi: settings.figures.dpi) }.map(\.id))
            : []
    }

    func isSelected(_ figure: HeavyFigure) -> Bool {
        settings.figures.selected.contains(figure.id)
    }

    func setSelected(_ figure: HeavyFigure, _ isSelected: Bool) {
        if isSelected {
            settings.figures.selected.insert(figure.id)
        } else {
            settings.figures.selected.remove(figure.id)
        }
    }

    /// ファイル 1 つの図の縮小表示を作る（シートでそのファイルの欄を出したときだけ）
    func loadThumbnails(_ file: WorkFile) async {
        guard let figures = figureReports[file.id]?.heavyFigures, !figures.isEmpty,
              figures.contains(where: { figureThumbnails[$0.id] == nil }),
              !loadingThumbnails.contains(file.id) else { return }
        loadingThumbnails.insert(file.id)
        defer { loadingThumbnails.remove(file.id) }
        guard let runner = try? QPDFRunner.locate(),
              let images = try? await FigureRasterizer(runner: runner).thumbnails(file.url, figures: figures, maxPixels: 240)
        else { return }
        figureThumbnails.merge(images) { _, new in new }
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
