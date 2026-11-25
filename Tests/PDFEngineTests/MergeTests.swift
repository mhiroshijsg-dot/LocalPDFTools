import Foundation
import PDFEngine
import Testing

@Suite("結合")
struct MergeTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    @Test("ページ数と順番（A 2 ページ → B 3 ページ）")
    func pagesAndOrder() async throws {
        let out = workspace.url("結合.pdf")
        let outcome = try await PDFMerger(runner: workspace.qpdf).merge([workspace.fileA, workspace.fileB], to: out)
        #expect(try workspace.pageWidths(out) == [300, 300, 400, 400, 400])
        #expect(outcome.inputBytes == FileSize.of(workspace.fileA)! + FileSize.of(workspace.fileB)!)
        #expect(outcome.outputBytes > 0)
    }

    @Test("逆の順番（B → A）")
    func reversedOrder() async throws {
        let out = workspace.url("結合-逆.pdf")
        _ = try await PDFMerger(runner: workspace.qpdf).merge([workspace.fileB, workspace.fileA], to: out)
        #expect(try workspace.pageWidths(out) == [400, 400, 400, 300, 300])
    }

    @Test("制限付きの PDF を混ぜても結合でき、出力は暗号化なし")
    func restrictedInput() async throws {
        let out = workspace.url("結合-制限付き.pdf")
        _ = try await PDFMerger(runner: workspace.qpdf).merge([try workspace.restrictedFile(), workspace.fileB], to: out)
        let info = try PDFInspector().inspect(out)
        #expect(info.pageCount == 5)
        #expect(!info.isEncrypted)
    }

    @Test("しおりの有無が分かり、結合するとしおりは消える（既知の制限）")
    func outlineIsDropped() async throws {
        let withOutline = try workspace.factory.makeWithOutline(name: "しおり付き.pdf", qpdf: workspace.qpdf.executableURL)
        #expect(try PDFInspector().inspect(withOutline).hasOutline)
        #expect(!(try PDFInspector().inspect(workspace.fileA).hasOutline))
        let out = workspace.url("結合-しおり.pdf")
        _ = try await PDFMerger(runner: workspace.qpdf).merge([withOutline, workspace.fileA], to: out)
        // 残るようになったら、画面の「しおりは残りません」の表示を見直す
        #expect(!(try PDFInspector().inspect(out).hasOutline))
    }
}
