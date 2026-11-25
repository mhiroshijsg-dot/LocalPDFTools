import Foundation

/// ページを回す。qpdf でページの向きの情報だけを変えるので、画質も大きさも変わらない。
public struct PDFRotator {
    let runner: QPDFRunner
    let writer = OutputWriter()

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    public func rotate(_ input: URL, plan: RotationPlan, to destination: URL) async throws -> OperationOutcome {
        try await writer.write(to: destination, inputs: [input]) { temporary in
            // MEMO(2026-11-25・by claude): 暗号化された入力は qpdf の既定どおり同じ暗号化のまま書き出す（勝手に外さない）。
            let arguments = [input.path, temporary.path] + plan.qpdfArguments()
            return try await runner.runChecked(arguments).warningLines
        }
    }
}
