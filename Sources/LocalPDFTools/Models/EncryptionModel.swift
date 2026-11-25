import Foundation
import Observation
import PDFEngine

/// 暗号化の解除の画面の状態と操作（1 つの PDF を扱う）
@MainActor
@Observable
final class EncryptionModel {
    private(set) var fileURL: URL?
    private(set) var fileBytes: Int64 = 0
    private(set) var report: EncryptionReport?
    /// 開くのにパスワードが要る PDF のときだけ使う。保存もしないし、画面を閉じれば消える
    var password = ""
    var outputName = ""
    var messages: [UserMessage] = []
    var outcome: OperationOutcome?
    var isWorking = false

    var needsPassword: Bool { report?.status == .passwordRequired }

    var canSave: Bool {
        guard let report, !isWorking else { return false }
        switch report.status {
        case .notEncrypted: return false
        case .restricted: return true
        case .passwordRequired: return !password.isEmpty
        }
    }

    func load(_ urls: [URL]) async {
        messages = []
        outcome = nil
        guard let url = urls.first else { return }
        if urls.count > 1 {
            messages.append(.note("暗号化の解除は 1 つずつ行います。最初のファイルだけを開きました: \(url.lastPathComponent)"))
        }
        guard url.pathExtension.lowercased() == "pdf" else {
            messages.append(.error("PDF ではありません: \(url.lastPathComponent)"))
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let inspector = PDFEncryptionInspector(runner: try QPDFRunner.locate())
            show(try await inspector.inspect(url), for: url)
        } catch {
            messages.append(.error(error.localizedDescription))
        }
    }

    /// 調べた結果を画面に出す（プレビューの見本からも使う）
    func show(_ report: EncryptionReport, for url: URL) {
        fileURL = url
        fileBytes = FileSize.of(url) ?? 0
        self.report = report
        password = ""
        outputName = url.deletingPathExtension().lastPathComponent + "-unlocked.pdf"
        if report.status == .notEncrypted {
            messages.append(.note("この PDF は暗号化されていません。外すものは無いので、そのまま結合・回転などに使えます。"))
        }
    }

    func close() {
        fileURL = nil
        fileBytes = 0
        report = nil
        password = ""
        messages = []
        outcome = nil
    }

    /// 保存先を選ばせてから、暗号化を外して保存する
    func decryptAndSave() async {
        messages = []
        outcome = nil
        guard let fileURL, canSave else { return }
        guard let destination = FilePanels().chooseDestination(
            suggestedName: OutputName.withPDFExtension(outputName),
            nextTo: fileURL) else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let decryptor = PDFDecryptor(runner: try QPDFRunner.locate())
            let result = try await decryptor.decrypt(fileURL, password: needsPassword ? password : nil, to: destination)
            outcome = result
            password = ""
            messages = [.note("保存した PDF が暗号化されていないことを確かめました。")]
                + result.warnings.map { .warning("qpdf の警告: \($0)") }
        } catch {
            messages = [.error(error.localizedDescription)]
        }
    }
}
