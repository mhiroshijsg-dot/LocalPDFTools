import Foundation
import PDFEngine
import Testing

@Suite("暗号化の判定と解除")
struct EncryptionTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    var inspector: PDFEncryptionInspector { PDFEncryptionInspector(runner: workspace.qpdf) }
    var decryptor: PDFDecryptor { PDFDecryptor(runner: workspace.qpdf) }

    // MARK: 判定

    @Test("暗号化なしの PDF は「暗号化なし」")
    func plain() async throws {
        let report = try await inspector.inspect(workspace.fileA)
        #expect(report.status == .notEncrypted)
    }

    @Test("ETS 型は「開けるが制限付き」・AES-256・コピーと編集が禁止")
    func restricted() async throws {
        let report = try await inspector.inspect(try workspace.restrictedFile())
        #expect(report.status == .restricted)
        #expect(report.method == "AES-256")
        let denied = try #require(report.deniedPermissions)
        #expect(denied.contains(.extract))
        #expect(denied.contains(.modifyOther))
        // 読み上げは qpdf の既定で許可のまま
        #expect(!denied.contains(.accessibility))
    }

    @Test("印刷も禁止の PDF では「印刷」と出し、「高画質の印刷」は省く")
    func printDenied() async throws {
        let noPrint = try workspace.factory.encrypt(workspace.fileA, name: "印刷禁止.pdf", userPassword: "",
                                                    qpdf: workspace.qpdf.executableURL,
                                                    restrictions: ["--print=none", "--modify=none", "--extract=n"])
        let report = try await inspector.inspect(noPrint)
        let denied = try #require(report.deniedPermissions)
        #expect(denied.contains(.printLow) && denied.contains(.printHigh))
        let summary = try #require(report.deniedSummary)
        #expect(summary.hasPrefix("印刷・"))
        #expect(!summary.contains("高画質の印刷"))
    }

    @Test("パスワードが要る PDF は、パスワードなしでは「パスワードが要る」とだけ分かる")
    func passwordRequired() async throws {
        let report = try await inspector.inspect(try workspace.lockedFile())
        #expect(report == EncryptionReport(status: .passwordRequired, method: nil, deniedPermissions: nil))
    }

    @Test("正しいパスワードを入れると、方式まで分かる")
    func passwordRequiredWithPassword() async throws {
        let report = try await inspector.inspect(try workspace.lockedFile(), password: "user-secret")
        #expect(report.status == .passwordRequired)
        #expect(report.method == "AES-256")
    }

    @Test("間違ったパスワードは「パスワードが違います」")
    func wrongPasswordOnInspect() async throws {
        let locked = try workspace.lockedFile()
        await #expect(throws: EngineError.wrongPassword(path: locked.path)) {
            _ = try await inspector.inspect(locked, password: "nope")
        }
    }

    @Test("PDF でないファイルは「読めません」")
    func notPDF() async throws {
        let broken = try workspace.brokenFile()
        await #expect(throws: EngineError.unreadablePDF(path: broken.path)) {
            _ = try await inspector.inspect(broken)
        }
    }

    // MARK: 解除

    @Test("ETS 型の制限を外せる: 出力は暗号化なし・ページ数は同じ・入力は 1 バイトも変わらない")
    func decryptRestricted() async throws {
        let restricted = try workspace.restrictedFile()
        let before = try workspace.sha(restricted)
        let out = workspace.url("解除.pdf")
        _ = try await decryptor.decrypt(restricted, password: nil, to: out)
        #expect(try await inspector.inspect(out).status == .notEncrypted)
        let document = try workspace.document(out)
        #expect(!document.isEncrypted)
        #expect(document.allowsCopying && document.allowsPrinting)
        #expect(document.pageCount == 2)
        #expect(try workspace.sha(restricted) == before)
    }

    @Test("パスワードが要る PDF を、正しいパスワードで外せる")
    func decryptWithPassword() async throws {
        let out = workspace.url("解除-パスワード.pdf")
        _ = try await decryptor.decrypt(try workspace.lockedFile(), password: "user-secret", to: out)
        #expect(try await inspector.inspect(out).status == .notEncrypted)
        #expect(try workspace.document(out).pageCount == 2)
    }

    @Test("日本語と空白を含むパスワードでも外せる")
    func decryptWithJapanesePassword() async throws {
        let out = workspace.url("解除-日本語.pdf")
        _ = try await decryptor.decrypt(try workspace.lockedFile(password: "パス ワード"), password: "パス ワード", to: out)
        #expect(try await inspector.inspect(out).status == .notEncrypted)
    }

    @Test("間違ったパスワードでは止まり、保存先は作られない")
    func decryptWithWrongPassword() async throws {
        let locked = try workspace.lockedFile()
        let out = workspace.url("作られない.pdf")
        await #expect(throws: EngineError.wrongPassword(path: locked.path)) {
            _ = try await decryptor.decrypt(locked, password: "nope", to: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    @Test("保存先 = 入力 なら止まる")
    func decryptOntoInput() async throws {
        let restricted = try workspace.restrictedFile()
        await #expect(throws: EngineError.outputSameAsInput(path: restricted.path)) {
            _ = try await decryptor.decrypt(restricted, password: nil, to: restricted)
        }
    }

    @Test("解除した PDF は、結合・回転の読み込みで「制限あり」にならない")
    func decryptedIsPlainForOtherTools() async throws {
        let out = workspace.url("解除-読み込み.pdf")
        _ = try await decryptor.decrypt(try workspace.restrictedFile(), password: nil, to: out)
        #expect(!(try PDFInspector().inspect(out).isEncrypted))
    }
}
