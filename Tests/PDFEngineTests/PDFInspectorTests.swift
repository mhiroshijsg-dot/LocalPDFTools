import Foundation
import PDFEngine
import Testing

@Suite("読み込み")
struct PDFInspectorTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    @Test("開けるが編集禁止の PDF（ETS 型）は読める・暗号化ありと分かる")
    func restricted() throws {
        let info = try PDFInspector().inspect(try workspace.restrictedFile())
        #expect(info.isEncrypted)
        #expect(info.pageCount == 2)
    }

    @Test("パスワードが要る PDF は「パスワードが要る」と止まる")
    func passwordRequired() throws {
        let locked = try workspace.lockedFile()
        #expect(throws: EngineError.passwordRequired(path: locked.path)) {
            _ = try PDFInspector().inspect(locked)
        }
    }

    @Test("PDF でないファイルは「読めません」")
    func notPDF() throws {
        let broken = try workspace.brokenFile()
        #expect(throws: EngineError.unreadablePDF(path: broken.path)) {
            _ = try PDFInspector().inspect(broken)
        }
    }
}
