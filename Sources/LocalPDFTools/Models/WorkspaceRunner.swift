import Foundation
import PDFEngine

/// 「実行して保存…」の流れ: 保護を外す確認 → 保存ダイアログ → 処理（パスワードは要る時点で聞く）→ 結果
@MainActor
struct WorkspaceRunner {
    let workspace: Workspace

    func run() async {
        workspace.messages = []
        workspace.outcomes = []
        guard workspace.blocker == nil else { return }
        let steps = OperationOrder.current().filter(workspace.selected.contains)

        let unlocking = workspace.filesLosingProtection
        if !unlocking.isEmpty {
            guard UnlockConfirmation().ask(fileNames: unlocking.map(\.fileName),
                                           byMergeOnly: !steps.contains(.decrypt)) else { return }
        }

        let pipeline: PDFPipeline
        do {
            pipeline = PDFPipeline(runner: try QPDFRunner.locate())
        } catch {
            workspace.messages = [.error(error.localizedDescription)]
            return
        }

        workspace.isWorking = true
        defer { workspace.isWorking = false }
        if steps.contains(.merge) {
            await runMerged(pipeline, steps: steps)
        } else {
            await runSeparately(pipeline, steps: steps)
        }
        guard !workspace.outcomes.isEmpty else { return }
        if steps.contains(.decrypt) && !unlocking.isEmpty {
            workspace.messages.append(.note("保護を外した PDF が暗号化されていないことを確かめてから保存しました。"))
        }
        // 解除も結合もしないとき、回転・圧縮は暗号化を保ったまま書き出す（勝手に外さない）
        if !steps.contains(.decrypt) && !steps.contains(.merge)
            && workspace.files.contains(where: { $0.isEncrypted && !$0.effectiveSteps(steps).isEmpty }) {
            workspace.messages.append(.note("暗号化（編集・印刷などの制限）のある PDF は、制限を付けたまま保存しました。"))
        }
    }

    /// 結合あり: 出力は 1 つ
    private func runMerged(_ pipeline: PDFPipeline, steps: [PipelineStep]) async {
        guard let destination = FilePanels().chooseDestination(
            suggestedName: OutputName.withPDFExtension(workspace.outputName),
            in: workspace.saveFolder) else { return }
        do {
            let outcome = try await pipeline.run(workspace.files.map(\.pipelineFile), steps: steps,
                                                 compression: workspace.compression.settings,
                                                 to: destination, askPassword: PasswordPrompt.ask)
            record(outcome)
        } catch {
            workspace.messages.append(.error(error.localizedDescription))
        }
    }

    /// 結合なし: 1 ファイルずつ、保存ダイアログを出して順に処理する。
    /// キャンセルしたファイルは飛ばして次へ進み、最後に飛ばしたファイルを知らせる
    private func runSeparately(_ pipeline: PDFPipeline, steps: [PipelineStep]) async {
        var skipped: [String] = []
        var nothingToDo: [String] = []
        let single = workspace.files.count == 1
        for file in workspace.files {
            let fileSteps = file.effectiveSteps(steps)
            if fileSteps.isEmpty {
                nothingToDo.append(file.fileName)
                continue
            }
            let name = single ? OutputName.withPDFExtension(workspace.outputName)
                              : SuggestedName.single(file.url, steps: fileSteps)
            let folder = workspace.chosenFolder ?? file.url.deletingLastPathComponent()
            guard let destination = FilePanels().chooseDestination(suggestedName: name, in: folder,
                                                                   message: single ? nil : "「\(file.fileName)」の保存先") else {
                skipped.append(file.fileName)
                continue
            }
            do {
                let outcome = try await pipeline.run([file.pipelineFile], steps: fileSteps,
                                                     compression: workspace.compression.settings,
                                                     to: destination, askPassword: PasswordPrompt.ask)
                record(outcome)
            } catch EngineError.passwordCancelled {
                skipped.append(file.fileName)
            } catch {
                workspace.messages.append(.error("\(file.fileName): \(error.localizedDescription)"))
            }
        }
        if !nothingToDo.isEmpty {
            workspace.messages.append(.note("行う操作が無いので保存しなかったファイル: " + nothingToDo.joined(separator: "、")))
        }
        if !skipped.isEmpty {
            workspace.messages.append(.warning("キャンセルしたので保存しなかったファイル: " + skipped.joined(separator: "、")))
        }
    }

    private func record(_ outcome: OperationOutcome) {
        workspace.outcomes.append(outcome)
        workspace.messages += outcome.warnings.map { .warning("qpdf の警告: \($0)") }
        guard let compression = outcome.compression else { return }
        let name = outcome.destination.lastPathComponent
        var done: [String] = []
        if compression.flattenedFigures > 0 { done.append("図 \(compression.flattenedFigures) 個を画像にし") }
        let lines = compression.vector
        if lines.gridLines > 0 { done.append("補助グリッド線 \(lines.gridLines) 本を消し") }
        if lines.tickMarks > 0 { done.append("補助目盛 \(lines.tickMarks) 本を消し") }
        if lines.pointsBefore > lines.pointsAfter {
            done.append("曲線の点を \(lines.pointsBefore) → \(lines.pointsAfter) 個に間引き")
        }
        if compression.resampledImages > 0 { done.append("画像 \(compression.resampledImages) 個の解像度を下げ") }
        if compression.requalifiedImages > 0 { done.append("画像 \(compression.requalifiedImages) 個の JPEG の画質を下げ") }
        // いつも行う 3 つ（見た目は変わらない・ほぼ変わらない）
        if compression.grayImages > 0 { done.append("色の無い画像 \(compression.grayImages) 個を灰色で保存し直し") }
        if compression.mergedDuplicates > 0 { done.append("重複していた部品 \(compression.mergedDuplicates) 個を 1 つにまとめ") }
        if compression.convertedFonts > 0 { done.append("フォント \(compression.convertedFonts) 個を小さな形式（CFF）に作り直し") }
        if compression.removedExtras > 0 { done.append("編集用のデータなど要らないデータ \(compression.removedExtras) 個を捨て") }
        var text = done.isEmpty ? "\(name): 画像と図の線は変えていません" : "\(name): " + done.joined(separator: "、") + "ました"
        if compression.keptImages > 0 { text += "（作り直しても小さくならなかった \(compression.keptImages) 個は元のまま）" }
        if compression.keptFigures > 0 { text += "（画像にしても小さくならなかった図 \(compression.keptFigures) 個は元のまま）" }
        workspace.messages.append(.note(text + "。"))
        // 計画 §4.2: 元より大きくなったら赤字で知らせる（元のファイルを黙って使ったりはしない）
        if outcome.outputBytes > outcome.inputBytes {
            workspace.messages.append(.warning("\(name) は元より大きくなりました（元 \(FileSize.text(outcome.inputBytes)) → 新 \(FileSize.text(outcome.outputBytes))）。元のファイルを使うことも考えてください。"))
        }
    }
}
