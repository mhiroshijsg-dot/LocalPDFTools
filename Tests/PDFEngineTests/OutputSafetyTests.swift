import Foundation
import PDFEngine
import Testing

/// 保存で元のファイルや既存のファイルを壊さないこと
@Suite("保存の安全")
struct OutputSafetyTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    @Test("保存先 = 入力 なら止まり、入力は 1 バイトも変わらない")
    func sameAsInput() async throws {
        let fileA = workspace.fileA
        let before = try workspace.sha(fileA)
        await #expect(throws: EngineError.outputSameAsInput(path: fileA.path)) {
            _ = try await PDFMerger(runner: workspace.qpdf).merge([fileA, workspace.fileB], to: fileA)
        }
        #expect(try workspace.sha(fileA) == before)
    }

    @Test("保存先 = 入力（大文字・小文字だけ違う名前）でも止まる")
    func sameAsInputDifferentCase() async throws {
        let differentCase = workspace.url("成績 a.pdf")
        // 大文字・小文字を区別するディスクでは別のファイルなので対象外
        try #require(FileManager.default.fileExists(atPath: differentCase.path))
        await #expect(throws: EngineError.outputSameAsInput(path: differentCase.path)) {
            _ = try await PDFRotator(runner: workspace.qpdf)
                .rotate(workspace.fileA, plan: RotationPlan(pageCount: 2), to: differentCase)
        }
    }

    @Test("既にある別のファイルへの上書き（保存ダイアログで確認済みの想定）")
    func overwritesOtherFile() async throws {
        let existing = try workspace.factory.make(name: "既存.pdf", pageSizes: [TestWorkspace.portrait])
        _ = try await PDFMerger(runner: workspace.qpdf).merge([workspace.fileA, workspace.fileB], to: existing)
        #expect(try workspace.document(existing).pageCount == 5)
    }

    @Test("qpdf が失敗したら、保存先は作られず元のファイルも残る")
    func failureLeavesFilesAlone() async throws {
        let broken = try workspace.brokenFile()
        let merger = PDFMerger(runner: workspace.qpdf)

        let fresh = workspace.url("作られない.pdf")
        let error = await #expect(throws: EngineError.self) {
            _ = try await merger.merge([workspace.fileA, broken], to: fresh)
        }
        guard case .qpdfFailed(_, let message)? = error else {
            Issue.record("qpdf の失敗として扱われていない: \(String(describing: error))")
            return
        }
        #expect(!message.isEmpty, "qpdf の報告が空")
        #expect(!FileManager.default.fileExists(atPath: fresh.path), "保存先ができてしまった")

        let existing = try workspace.factory.make(name: "残る.pdf", pageSizes: [TestWorkspace.portrait])
        let before = try workspace.sha(existing)
        await #expect(throws: EngineError.self) {
            _ = try await merger.merge([workspace.fileA, broken], to: existing)
        }
        #expect(try workspace.sha(existing) == before, "既存のファイルが壊れた")
    }
}
