import Foundation
import Observation
import PDFEngine
import PDFKit

/// 作業台に入れた PDF 1 つ分（情報・暗号化の状態・ページの回し方）。
/// パスワードは持たない（要る時点で聞いて、その場で qpdf に渡すだけ）。
@MainActor
@Observable
final class WorkFile: Identifiable {
    let id = UUID()
    let url: URL
    let byteSize: Int64
    /// パスワードが要る PDF は、開くまでページ数が分からないので nil
    let pageCount: Int?
    let encryption: EncryptionReport
    let hasOutline: Bool
    let thumbnails = ThumbnailCache()
    /// 圧縮の分析の結果（圧縮をオンにしたときに初めて作る）
    var contentReport: PDFContentReport?
    /// 分析できなかった理由
    var analysisError: String?
    /// 図の線を減らすと減る数（「図の線を減らす」を初めてオンにしたときに数える）
    var thinningReport: VectorThinningReport?
    /// 縮小表示を作るときに初めて開く
    private(set) var document: PDFDocument?
    /// 保存に使う向き（ページごとに 0〜3 回の 90°）
    private(set) var plan: RotationPlan
    /// 画面で傾ける角度（90° 単位）。0〜3 に丸めずに足し続ける。
    /// MEMO(2026-11-25・by claude): 丸めた値で動きを付けると、270° → 0° のときに右へ 90° ではなく
    /// 左へ 270° 戻って見えた。そこで表示用は丸めない値を別に持つ。
    private(set) var displayTurns: [Int]

    init(url: URL, byteSize: Int64, pageCount: Int?, encryption: EncryptionReport, hasOutline: Bool) {
        self.url = url
        self.byteSize = byteSize
        self.pageCount = pageCount
        self.encryption = encryption
        self.hasOutline = hasOutline
        plan = RotationPlan(pageCount: pageCount ?? 0)
        displayTurns = Array(repeating: 0, count: pageCount ?? 0)
    }

    /// 暗号化を調べてから、開ける PDF ならページ数などを読む
    static func load(_ url: URL, runner: QPDFRunner) async throws -> WorkFile {
        let report = try await PDFEncryptionInspector(runner: runner).inspect(url)
        if report.status == .passwordRequired {
            return WorkFile(url: url, byteSize: FileSize.of(url) ?? 0, pageCount: nil, encryption: report, hasOutline: false)
        }
        let info = try PDFInspector().inspect(url)
        return WorkFile(url: url, byteSize: info.byteSize, pageCount: info.pageCount, encryption: report, hasOutline: info.hasOutline)
    }

    var fileName: String { url.lastPathComponent }
    var isLocked: Bool { encryption.status == .passwordRequired }
    var isEncrypted: Bool { encryption.status != .notEncrypted }
    var rotatedPageCount: Int { plan.quarterTurns.filter { $0 != 0 }.count }

    /// 縮小表示のために開く（パスワードが要るものは開かない）
    func openDocument() -> PDFDocument? {
        if document == nil && !isLocked {
            document = PDFDocument(url: url)
        }
        return document
    }

    /// turns は正なら時計回り、負なら反時計回り
    func rotate(pageIndex: Int, by turns: Int) {
        guard displayTurns.indices.contains(pageIndex) else { return }
        plan.rotate(pageIndex: pageIndex, by: turns)
        displayTurns[pageIndex] += turns
    }

    func rotateAll(by turns: Int) {
        for index in displayTurns.indices {
            rotate(pageIndex: index, by: turns)
        }
    }

    /// このページを元の向きへ、近い側を回って戻す（270° なら右へ 90°、90° なら左へ 90°）
    func resetPage(_ pageIndex: Int) {
        guard plan.quarterTurns.indices.contains(pageIndex) else { return }
        let turns = plan.quarterTurns[pageIndex]
        rotate(pageIndex: pageIndex, by: turns <= 2 ? -turns : 4 - turns)
    }

    func resetRotation() {
        for index in displayTurns.indices {
            resetPage(index)
        }
    }

    /// 処理の部品に渡す形
    var pipelineFile: PipelineFile {
        PipelineFile(url: url, encryption: encryption.status, rotation: plan)
    }

    /// 選んだ操作のうち、このファイルに実際に効くもの（結合は除く）
    func effectiveSteps(_ steps: [PipelineStep]) -> [PipelineStep] {
        steps.filter { step in
            switch step {
            case .decrypt: return isEncrypted
            case .rotate: return plan.hasChanges
            case .merge: return false
            case .compress: return true
            }
        }
    }

    /// 札のヒントに出す暗号化の詳しい内容
    var encryptionDetail: String {
        var lines: [String] = []
        switch encryption.status {
        case .notEncrypted: return ""
        case .restricted: lines.append("開けるが、編集・印刷などが制限されている")
        case .passwordRequired: lines.append("開くのにパスワードが要る（パスワードは実行中に聞きます）")
        }
        if let method = encryption.method { lines.append("暗号の方式: \(method)") }
        if let summary = encryption.deniedSummary { lines.append("禁止されている操作: \(summary)") }
        return lines.joined(separator: "\n")
    }
}
