import Foundation
import Observation
import PDFEngine
import PDFKit

/// 回転の画面の状態と操作（1 つの PDF を扱う）
@MainActor
@Observable
final class RotateModel {
    private(set) var file: PDFFileInfo?
    /// 縮小表示を作るために開いておく
    private(set) var document: PDFDocument?
    let thumbnails = ThumbnailCache()
    /// 保存に使う向き（ページごとに 0〜3 回の 90°）
    private(set) var plan = RotationPlan(pageCount: 0)
    /// 画面で傾ける角度（90° 単位）。0〜3 に丸めずに足し続ける。
    /// MEMO(2026-11-25・by claude): 丸めた値で動きを付けると、270° → 0° のときに右へ 90° ではなく
    /// 左へ 270° 戻って見えた。そこで表示用は丸めない値を別に持つ。
    private(set) var displayTurns: [Int] = []
    var outputName = ""
    var messages: [UserMessage] = []
    var outcome: OperationOutcome?
    var isWorking = false

    var canSave: Bool { file != nil && plan.hasChanges && !isWorking }

    func load(_ urls: [URL]) {
        messages = []
        outcome = nil
        guard let url = urls.first else { return }
        if urls.count > 1 {
            messages.append(.note("回転は 1 つずつ行います。最初のファイルだけを開きました: \(url.lastPathComponent)"))
        }
        guard url.pathExtension.lowercased() == "pdf" else {
            messages.append(.error("PDF ではありません: \(url.lastPathComponent)"))
            return
        }
        do {
            let info = try PDFInspector().inspect(url)
            file = info
            document = PDFDocument(url: url)
            thumbnails.removeAll()
            plan = RotationPlan(pageCount: info.pageCount)
            displayTurns = Array(repeating: 0, count: info.pageCount)
            outputName = url.deletingPathExtension().lastPathComponent + "-rotated.pdf"
        } catch {
            messages.append(.error(error.localizedDescription))
        }
    }

    func close() {
        file = nil
        document = nil
        thumbnails.removeAll()
        plan = RotationPlan(pageCount: 0)
        displayTurns = []
        messages = []
        outcome = nil
    }

    /// turns は正なら時計回り、負なら反時計回り
    func rotate(pageIndex: Int, by turns: Int) {
        guard displayTurns.indices.contains(pageIndex) else { return }
        plan.rotate(pageIndex: pageIndex, by: turns)
        displayTurns[pageIndex] += turns
        outcome = nil
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

    func reset() {
        for index in displayTurns.indices {
            resetPage(index)
        }
    }

    func save() async {
        messages = []
        outcome = nil
        guard let file else { return }
        guard let destination = FilePanels().chooseDestination(
            suggestedName: OutputName.withPDFExtension(outputName),
            nextTo: file.url) else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let rotator = PDFRotator(runner: try QPDFRunner.locate())
            let result = try await rotator.rotate(file.url, plan: plan, to: destination)
            outcome = result
            messages = result.warnings.map { .warning("qpdf の警告: \($0)") }
            if file.isEncrypted {
                messages.append(.note("元の PDF の暗号化（編集・印刷などの制限）はそのまま残しています。"))
            }
        } catch {
            messages = [.error(error.localizedDescription)]
        }
    }
}
