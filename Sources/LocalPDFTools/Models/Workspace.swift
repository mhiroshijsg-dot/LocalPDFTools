import Foundation
import Observation
import PDFEngine

/// 作業台（窓全体）の状態: 並べた PDF・チェックした操作・保存名と保存先・結果
@MainActor
@Observable
final class Workspace {
    var files: [WorkFile] = []
    /// チェックした操作
    var selected: Set<PipelineStep> = [] {
        didSet {
            // 結合を付け外しすると名前の形（_merge か _rotated など）が変わるので、書き換えた名前は捨てる
            if selected.contains(.merge) != oldValue.contains(.merge) { customName = nil }
            // 圧縮をオンにしたときに初めて中身を分析する（使わないなら読まない）
            if selected.contains(.compress) && !oldValue.contains(.compress) {
                Task {
                    await compression.analyze(files)
                    // 線を減らすのが既定でオンなので、圧縮をオンにした時点で減る本数を数えて見せる
                    if compression.settings.vector.isActive { await compression.countLines(files) }
                }
            }
        }
    }
    /// 圧縮のやり方・分析・目安・試算
    let compression = CompressionModel()
    /// 「文字の抽出」のスイッチ。PDF の保存の流れとは別（文字はシートで見てコピー・保存する。PDF は変えない）
    var extractsText = false {
        didSet {
            // オンにしたときに初めて文字の層を読む（使わないなら読まない）
            if extractsText && !oldValue { Task { await text.readLayers(files) } }
        }
    }
    /// 文字の抽出の状態（読んだ文字・OCR・保存の結果）
    let text = TextExtractionModel()
    /// 自分で書き換えた保存名（nil なら初期値を使う）
    private var customName: String?
    /// 「変更…」で選んだ保存先。その作業の間だけ使う（ファイルをすべて外すかアプリを閉じたら、元のファイルの場所に戻る）
    private(set) var chosenFolder: URL?
    var messages: [UserMessage] = []
    var outcomes: [OperationOutcome] = []
    var isWorking = false

    var totalPages: Int? {
        files.contains { $0.pageCount == nil } ? nil : files.reduce(0) { $0 + ($1.pageCount ?? 0) }
    }
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.byteSize } }
    var merges: Bool { selected.contains(.merge) }

    // MARK: ファイル

    /// ドロップや「開く」で入ったファイルを、末尾に足す（暗号化の状態もここで調べる）
    func add(_ urls: [URL]) async {
        messages = []
        outcomes = []
        isWorking = true
        defer { isWorking = false }
        let runner: QPDFRunner
        do {
            runner = try QPDFRunner.locate()
        } catch {
            messages.append(.error(error.localizedDescription))
            return
        }
        for url in urls {
            guard url.pathExtension.lowercased() == "pdf" else {
                messages.append(.error(String(localized: "PDF ではないので入れませんでした: \(url.lastPathComponent)")))
                continue
            }
            do {
                files.append(try await WorkFile.load(url, runner: runner))
            } catch {
                messages.append(.error(error.localizedDescription))
            }
        }
        compression.invalidateTrial()
        if selected.contains(.compress) {
            await compression.analyze(files)
            if compression.settings.vector.isActive { await compression.countLines(files) }
        }
        if extractsText { await text.readLayers(files) }
    }

    func remove(_ file: WorkFile) {
        text.forget(file)
        files.removeAll { $0.id == file.id }
        outcomes = []
        compression.invalidateTrial()
        if files.isEmpty { clear() }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        outcomes = []
    }

    func removeAll() {
        files = []
        clear()
    }

    private func clear() {
        compression.invalidateTrial()
        text.reset()
        customName = nil
        chosenFolder = nil
        messages = []
        outcomes = []
    }

    // MARK: 文字の抽出

    /// 指定したページを OCR する。「回転」がオンなら、回す指定をした向きに直してから読む
    func startOCR(_ file: WorkFile, pages: [Int]) {
        text.startOCR(file, pages: pages, quarterTurns: selected.contains(.rotate) ? file.plan.quarterTurns : [])
    }

    // MARK: 保存名と保存先

    /// 保存名の欄を出すか（結合しないで複数のファイルを保存するときは、名前はファイルごとのダイアログで決める）
    var hasSingleOutput: Bool { !files.isEmpty && (merges || files.count == 1) }

    var suggestedName: String {
        guard let first = files.first else { return "" }
        if merges { return SuggestedName.merged(top: first.url) }
        return SuggestedName.single(first.url, steps: first.effectiveSteps(OperationOrder.current().filter(selected.contains)))
    }

    /// 保存名の欄。並べ替えなどで初期値が変わっても、自分で書き換えた後は変えない
    var outputName: String {
        get { customName ?? suggestedName }
        set { customName = newValue }
    }

    /// 表示する保存先（nil は「それぞれの元のフォルダ」）
    var saveFolder: URL? {
        if let chosenFolder { return chosenFolder }
        return hasSingleOutput ? files.first?.url.deletingLastPathComponent() : nil
    }

    func changeFolder() {
        if let folder = FilePanels().chooseFolder(startingAt: saveFolder ?? files.first?.url.deletingLastPathComponent()) {
            chosenFolder = folder
        }
    }

    func resetFolder() {
        chosenFolder = nil
    }

    // MARK: 実行できるか

    /// 実行できない理由（実行できるなら nil）
    var blocker: String? {
        if files.isEmpty { return String(localized: "PDF を入れてください") }
        if selected.isEmpty { return String(localized: "行う操作にチェックを入れてください") }
        if merges && files.count < 2 { return String(localized: "結合するには 2 つ以上の PDF を入れてください") }
        if !selected.contains(.decrypt) && files.contains(where: \.isLocked) {
            return String(localized: "パスワードが要る PDF があります。「暗号化の解除」にチェックを入れてください")
        }
        if !merges && !files.contains(where: { !$0.effectiveSteps(Array(selected)).isEmpty }) {
            if selected.contains(.rotate) { return String(localized: "回すページを選んでください") }
            return String(localized: "暗号化された PDF が無いので、外すものがありません")
        }
        return nil
    }

    /// 保護（暗号化）が外れるファイル。解除にチェックがあれば暗号化されたもの全部。
    /// 解除なしでも、結合すると制限付きのファイルの制限は外れる（qpdf の結合は暗号化を引き継がない）
    var filesLosingProtection: [WorkFile] {
        if selected.contains(.decrypt) { return files.filter(\.isEncrypted) }
        if merges { return files.filter(\.isEncrypted) }
        return []
    }
}
