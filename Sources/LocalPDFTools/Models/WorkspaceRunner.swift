import Foundation
import PDFEngine

/// 「実行して保存…」の流れ: 保護を外す確認 → 保存ダイアログ → 処理（パスワードは要る時点で聞く）→ 結果
@MainActor
struct WorkspaceRunner {
    let workspace: Workspace

    func run() async {
        workspace.messages = []
        workspace.clearResults()
        guard workspace.blocker == nil else { return }
        let steps = OperationOrder.current().filter(workspace.selected.contains)

        let unlocking = workspace.filesLosingProtection
        if !unlocking.isEmpty {
            let droppedBy: Operation? = steps.contains(.decrypt) ? nil : (steps.contains(.split) ? .split : .merge)
            guard UnlockConfirmation().ask(fileNames: unlocking.map(\.fileName), droppedBy: droppedBy) else { return }
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
        if steps.contains(.split) {
            await runSplit(pipeline, steps: steps)
        } else if steps.contains(.merge) {
            await runMerged(pipeline, steps: steps)
        } else {
            await runSeparately(pipeline, steps: steps)
        }
        guard !workspace.outcomes.isEmpty || !workspace.splitOutcomes.isEmpty else { return }
        if steps.contains(.decrypt) && !unlocking.isEmpty {
            workspace.messages.append(.note(String(localized: "保護を外した PDF が暗号化されていないことを確かめてから保存しました。")))
        }
        // 解除も結合も分割もしないとき、回転・圧縮は暗号化を保ったまま書き出す（勝手に外さない）
        if !steps.contains(.decrypt) && !steps.contains(.merge) && !steps.contains(.split)
            && workspace.files.contains(where: { $0.isEncrypted && !$0.effectiveSteps(steps).isEmpty }) {
            workspace.messages.append(.note(String(localized: "暗号化（編集・印刷などの制限）のある PDF は、制限を付けたまま保存しました。")))
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
                                                                   message: single ? nil : String(localized: "「\(file.fileName)」の保存先")) else {
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
            workspace.messages.append(.note(String(localized: "行う操作が無いので保存しなかったファイル: \(ListText.join(nothingToDo))")))
        }
        if !skipped.isEmpty {
            workspace.messages.append(.warning(String(localized: "キャンセルしたので保存しなかったファイル: \(ListText.join(skipped))")))
        }
    }

    /// 分割あり: 新しいフォルダを作る場所を 1 回だけ選び、ファイルごとにフォルダを作って分けた PDF を入れる。
    /// パスワードの入力をやめたファイルは飛ばして次へ進み、最後に知らせる
    private func runSplit(_ pipeline: PDFPipeline, steps: [PipelineStep]) async {
        let single = workspace.files.count == 1
        let folderName = workspace.splitFolderName.trimmingCharacters(in: .whitespaces)
        let message = single
            ? String(localized: "ここに新しいフォルダ「\(folderName)」を作り、分けた PDF を入れます")
            : String(localized: "ここに、ファイルごとに新しいフォルダ（元の名前_split）を作り、分けた PDF を入れます")
        guard let parent = FilePanels().chooseSplitLocation(startingAt: workspace.saveFolder, message: message) else { return }
        var skipped: [String] = []
        for file in workspace.files {
            do {
                let outcome = try await pipeline.runSplit(file.pipelineFile, steps: file.effectiveSteps(steps),
                                                          split: workspace.split.plan,
                                                          compression: workspace.compression.settings,
                                                          baseName: SuggestedName.baseName(file.url),
                                                          folderName: single ? folderName : SuggestedName.splitFolder(file.url),
                                                          in: parent, askPassword: PasswordPrompt.ask)
                workspace.splitOutcomes.append(outcome)
                workspace.messages += outcome.warnings.map { .warning(String(localized: "qpdf の警告: \($0)")) }
                if let compression = outcome.compression {
                    noteCompression(compression, name: String(localized: "\(outcome.folder.lastPathComponent) の PDF"))
                }
            } catch EngineError.passwordCancelled {
                skipped.append(file.fileName)
            } catch {
                workspace.messages.append(.error("\(file.fileName): \(error.localizedDescription)"))
            }
        }
        if !skipped.isEmpty {
            workspace.messages.append(.warning(String(localized: "パスワードの入力をやめたので分けなかったファイル: \(ListText.join(skipped))")))
        }
    }

    private func record(_ outcome: OperationOutcome) {
        workspace.outcomes.append(outcome)
        workspace.messages += outcome.warnings.map { .warning(String(localized: "qpdf の警告: \($0)")) }
        guard let compression = outcome.compression else { return }
        let name = outcome.destination.lastPathComponent
        noteCompression(compression, name: name)
        // 計画 §4.2: 元より大きくなったら赤字で知らせる（元のファイルを黙って使ったりはしない）
        if outcome.outputBytes > outcome.inputBytes {
            workspace.messages.append(.warning(String(localized: "\(name) は元より大きくなりました（元 \(FileSize.text(outcome.inputBytes)) → 新 \(FileSize.text(outcome.outputBytes))）。元のファイルを使うことも考えてください。")))
        }
    }

    /// 圧縮で何をしたかの一文（name は保存したファイル・フォルダの名前）
    private func noteCompression(_ compression: CompressionResult, name: String) {
        var done: [String] = []
        if compression.flattenedFigures > 0 { done.append(String(localized: "図 \(compression.flattenedFigures) 個を画像にし")) }
        let lines = compression.vector
        if lines.gridLines > 0 { done.append(String(localized: "補助グリッド線 \(lines.gridLines) 本を消し")) }
        if lines.tickMarks > 0 { done.append(String(localized: "補助目盛 \(lines.tickMarks) 本を消し")) }
        if lines.pointsBefore > lines.pointsAfter {
            done.append(String(localized: "曲線の点を \(lines.pointsBefore) → \(lines.pointsAfter) 個に間引き"))
        }
        if compression.resampledImages > 0 { done.append(String(localized: "画像 \(compression.resampledImages) 個の解像度を下げ")) }
        if compression.requalifiedImages > 0 { done.append(String(localized: "画像 \(compression.requalifiedImages) 個の JPEG の画質を下げ")) }
        // いつも行う 3 つ（見た目は変わらない・ほぼ変わらない）
        if compression.grayImages > 0 { done.append(String(localized: "色の無い画像 \(compression.grayImages) 個を灰色で保存し直し")) }
        if compression.mergedDuplicates > 0 { done.append(String(localized: "重複していた部品 \(compression.mergedDuplicates) 個を 1 つにまとめ")) }
        if compression.convertedFonts > 0 { done.append(String(localized: "フォント \(compression.convertedFonts) 個を小さな形式（CFF）に作り直し")) }
        if compression.removedExtras > 0 { done.append(String(localized: "編集用のデータなど要らないデータ \(compression.removedExtras) 個を捨て")) }
        // MEMO(2026-11-27・by claude): 英語版（計画 A）。日本語は「…し、…しました。」、英語は「rasterized …, removed ….」になるよう、
        // 1 つずつの語（done）と、つなぎ・文の終わりを別々に訳す
        var text = done.isEmpty ? String(localized: "\(name): 画像と図の線は変えていません")
                                : String(localized: "\(name): \(ListText.join(done))ました")
        if compression.keptImages > 0 { text += String(localized: "（作り直しても小さくならなかった \(compression.keptImages) 個は元のまま）") }
        if compression.keptFigures > 0 { text += String(localized: "（画像にしても小さくならなかった図 \(compression.keptFigures) 個は元のまま）") }
        workspace.messages.append(.note(text + String(localized: "sentence.end", defaultValue: "。")))
    }
}
