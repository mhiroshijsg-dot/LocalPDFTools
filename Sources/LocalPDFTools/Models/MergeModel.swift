import Foundation
import Observation
import PDFEngine

/// 結合の画面の状態と操作
@MainActor
@Observable
final class MergeModel {
    var files: [PDFFileInfo] = []
    var outputName = "merged.pdf"
    var messages: [UserMessage] = []
    var outcome: OperationOutcome?
    var isWorking = false

    var totalPages: Int { files.reduce(0) { $0 + $1.pageCount } }
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.byteSize } }
    var canMerge: Bool { files.count >= 2 && !isWorking }
    var anyHasOutline: Bool { files.contains { $0.hasOutline } }

    /// ドロップや「開く」で入ったファイルを、末尾に足す
    func add(_ urls: [URL]) {
        messages = []
        outcome = nil
        for url in urls {
            guard url.pathExtension.lowercased() == "pdf" else {
                messages.append(.error("PDF ではないので入れませんでした: \(url.lastPathComponent)"))
                continue
            }
            do {
                files.append(try PDFInspector().inspect(url))
            } catch {
                messages.append(.error(error.localizedDescription))
            }
        }
    }

    func remove(_ file: PDFFileInfo) {
        files.removeAll { $0.id == file.id }
        outcome = nil
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        outcome = nil
    }

    func removeAll() {
        files = []
        messages = []
        outcome = nil
    }

    /// 保存先を選ばせてから結合する
    func mergeAndSave() async {
        messages = []
        outcome = nil
        guard files.count >= 2 else {
            messages = [.error("2 つ以上の PDF を入れてください。")]
            return
        }
        guard let destination = FilePanels().chooseDestination(
            suggestedName: OutputName.withPDFExtension(outputName),
            nextTo: files.first?.url) else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let merger = PDFMerger(runner: try QPDFRunner.locate())
            let result = try await merger.merge(files.map(\.url), to: destination)
            outcome = result
            messages = result.warnings.map { .warning("qpdf の警告: \($0)") }
        } catch {
            messages = [.error(error.localizedDescription)]
        }
    }
}
