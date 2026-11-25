import Foundation

/// PDF の暗号化の状態を調べる（中身は変えない）。
/// 中身は `qpdf --requires-password` と `qpdf --json --json-key=encrypt`。
public struct PDFEncryptionInspector {
    let runner: QPDFRunner

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// password を渡すと、パスワードが要る PDF でも方式と禁止の操作まで調べる。
    /// パスワードが違えば EngineError.wrongPassword を投げる。
    public func inspect(_ url: URL, password: String? = nil) async throws -> EncryptionReport {
        // --requires-password の終了コード: 0 = パスワードが要る、3 = 要らないが暗号化あり、2 = 暗号化なし（または読めない）
        let probe = try await runner.run(["--requires-password", url.path])
        let needsPassword = probe.exitCode == 0
        if needsPassword && password == nil {
            return EncryptionReport(status: .passwordRequired, method: nil, deniedPermissions: nil)
        }

        let passwordArguments = needsPassword ? QPDFPassword.arguments : []
        let output = try await runner.run(passwordArguments + ["--json", "--json-key=encrypt", url.path],
                                          input: needsPassword ? QPDFPassword.input(password) : nil)
        if output.isInvalidPassword {
            throw EngineError.wrongPassword(path: url.path)
        }
        guard output.exitCode == 0,
              let json = try? JSONDecoder().decode(QPDFEncryptionJSON.self, from: Data(output.standardOutput.utf8)) else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        guard json.encrypt.encrypted else {
            return EncryptionReport(status: .notEncrypted, method: nil, deniedPermissions: [])
        }
        return EncryptionReport(status: needsPassword ? .passwordRequired : .restricted,
                                method: json.methodName,
                                deniedPermissions: json.deniedPermissions)
    }
}
