import Foundation

/// 暗号化を外す（編集・印刷などの制限と、開くときのパスワードの両方）。
/// 中身は `qpdf --decrypt`。ページを作り直さないので、文字・画質・大きさは変わらない。
/// 本人が権利を持つ書類に使う前提（画面にも書く）。パスワードは本人が入力したときだけ使う。
public struct PDFDecryptor {
    let runner: QPDFRunner
    let writer = OutputWriter()

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// password は開くのにパスワードが要る PDF のときだけ渡す。
    /// 保存先へ移す前に、出力が本当に暗号化なしかを確かめる（まだ暗号化されていたら保存しない）。
    public func decrypt(_ input: URL, password: String?, to destination: URL) async throws -> OperationOutcome {
        try await writer.write(to: destination, inputs: [input]) { temporary in
            try await decryptFile(input, password: password, into: temporary)
        }
    }

    /// 一時ファイル output に暗号化なしの PDF を作る（結合・回転と続けて行うときに使う）。qpdf の警告の行を返す。
    /// MEMO(2026-11-26・by claude): パスワードはこの関数の引数として受け取り、qpdf の標準入力へ渡すだけ。どこにも残さない。
    public func decryptFile(_ input: URL, password: String?, into output: URL) async throws -> [String] {
        let passwordArguments = password == nil ? [] : QPDFPassword.arguments
        let result = try await runner.run(passwordArguments + ["--decrypt", input.path, output.path],
                                          input: password.map { QPDFPassword.input($0) })
        if result.isInvalidPassword {
            throw EngineError.wrongPassword(path: input.path)
        }
        guard result.succeeded else {
            throw EngineError.qpdfFailed(exitCode: result.exitCode,
                                         message: result.standardError.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let check = try await PDFEncryptionInspector(runner: runner).inspect(output)
        guard check.status == .notEncrypted else {
            throw EngineError.stillEncrypted(path: input.path)
        }
        return result.warningLines
    }
}
