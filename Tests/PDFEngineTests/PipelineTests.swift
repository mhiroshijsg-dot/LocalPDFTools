import Foundation
import PDFEngine
import Testing

@Suite("続けて処理（解除 → 回転 → 結合）")
struct PipelineTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    var pipeline: PDFPipeline { PDFPipeline(runner: workspace.qpdf) }

    /// 2 ページ目を右に 90°
    func secondPageRight(pageCount: Int) -> RotationPlan {
        var plan = RotationPlan(pageCount: pageCount)
        plan.rotate(pageIndex: 1, by: 1)
        return plan
    }

    @Test("ファイルごとの回転の指定を、結合後の通しの番号につなげる")
    func joinedPlan() {
        var a = RotationPlan(pageCount: 2)
        a.rotate(pageIndex: 1, by: 1)
        var b = RotationPlan(pageCount: 3)
        b.rotate(pageIndex: 0, by: 2)
        // 3 つ目はページ数が分からなかった（指定なし）が、実際は 2 ページ
        let joined = RotationPlan.joined([a, b, RotationPlan(pageCount: 0)], pageCounts: [2, 3, 2])
        #expect(joined.quarterTurns == [0, 1, 2, 0, 0, 0, 0])
    }

    @Test("解除＋回転＋結合を一度にした結果が、1 つずつ行った結果と同じ・入力は 1 バイトも変わらない")
    func sameAsOneByOne() async throws {
        let restricted = try workspace.restrictedFile()
        let fileB = workspace.fileB
        let before = [try workspace.sha(restricted), try workspace.sha(fileB)]

        // 1 つずつ
        let unlocked = workspace.url("1-解除.pdf")
        _ = try await PDFDecryptor(runner: workspace.qpdf).decrypt(restricted, password: nil, to: unlocked)
        let rotatedA = workspace.url("1-回転A.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(unlocked, plan: secondPageRight(pageCount: 2), to: rotatedA)
        let rotatedB = workspace.url("1-回転B.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(fileB, plan: secondPageRight(pageCount: 3), to: rotatedB)
        let oneByOne = workspace.url("1-結合.pdf")
        _ = try await PDFMerger(runner: workspace.qpdf).merge([rotatedA, rotatedB], to: oneByOne)

        // 一度に
        let together = workspace.url("一度に.pdf")
        let files = [PipelineFile(url: restricted, encryption: .restricted, rotation: secondPageRight(pageCount: 2)),
                     PipelineFile(url: fileB, encryption: .notEncrypted, rotation: secondPageRight(pageCount: 3))]
        _ = try await pipeline.run(files, steps: [.decrypt, .rotate, .merge], to: together) { _, _ in
            Issue.record("パスワードの要らない PDF でパスワードを聞いた")
            return nil
        }

        #expect(try workspace.pageRotations(together) == [0, 90, 0, 90, 0])
        #expect(try workspace.pageRotations(together) == workspace.pageRotations(oneByOne))
        #expect(try workspace.pageWidths(together) == workspace.pageWidths(oneByOne))
        #expect(try await PDFEncryptionInspector(runner: workspace.qpdf).inspect(together).status == .notEncrypted)
        #expect([try workspace.sha(restricted), try workspace.sha(fileB)] == before)
    }

    @Test("結合の後に回しても、結合の前に回したのと同じ（パスワードが要ってページ数の分からないファイルを含む）")
    func rotateAfterMerge() async throws {
        let locked = try workspace.lockedFile()
        let files = [PipelineFile(url: locked, encryption: .passwordRequired, rotation: RotationPlan(pageCount: 0)),
                     PipelineFile(url: workspace.fileB, encryption: .notEncrypted, rotation: secondPageRight(pageCount: 3))]
        let before = workspace.url("回転が先.pdf")
        let after = workspace.url("結合が先.pdf")
        _ = try await pipeline.run(files, steps: [.decrypt, .rotate, .merge], to: before) { _, _ in "user-secret" }
        _ = try await pipeline.run(files, steps: [.decrypt, .merge, .rotate], to: after) { _, _ in "user-secret" }
        #expect(try workspace.pageRotations(after) == [0, 0, 0, 90, 0])
        #expect(try workspace.pageRotations(after) == workspace.pageRotations(before))
    }

    @Test("パスワードは要るファイルだけで聞く・違えば聞き直す")
    func asksOnlyWhenNeeded() async throws {
        let locked = try workspace.lockedFile()
        let files = [PipelineFile(url: try workspace.restrictedFile(), encryption: .restricted, rotation: RotationPlan(pageCount: 2)),
                     PipelineFile(url: locked, encryption: .passwordRequired, rotation: RotationPlan(pageCount: 0))]
        let asked = AskLog(answers: ["nope", "user-secret"])
        let out = workspace.url("聞き直し.pdf")
        _ = try await pipeline.run(files, steps: [.decrypt, .merge], to: out, askPassword: asked.answer)
        #expect(await asked.calls == [AskLog.Call(file: locked, isRetry: false), AskLog.Call(file: locked, isRetry: true)])
        #expect(try workspace.document(out).pageCount == 4)
    }

    @Test("パスワードの入力をやめたら止まり、保存先は作られない・途中のファイルも残らない")
    func cancelPassword() async throws {
        let locked = try workspace.lockedFile()
        let out = workspace.url("作られない.pdf")
        let before = try FileManager.default.contentsOfDirectory(atPath: workspace.directory.path).sorted()
        let files = [PipelineFile(url: locked, encryption: .passwordRequired, rotation: RotationPlan(pageCount: 0))]
        await #expect(throws: EngineError.passwordCancelled(path: locked.path)) {
            _ = try await pipeline.run(files, steps: [.decrypt], to: out) { _, _ in nil }
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.directory.path).sorted() == before)
    }

    @Test("成功しても、保存先のフォルダに途中のファイルが残らない")
    func noLeftovers() async throws {
        let restricted = try workspace.restrictedFile()
        let before = try FileManager.default.contentsOfDirectory(atPath: workspace.directory.path)
        let out = workspace.url("できあがり.pdf")
        let files = [PipelineFile(url: restricted, encryption: .restricted, rotation: secondPageRight(pageCount: 2))]
        _ = try await pipeline.run(files, steps: [.decrypt, .rotate], to: out) { _, _ in nil }
        let after = try FileManager.default.contentsOfDirectory(atPath: workspace.directory.path)
        #expect(Set(after) == Set(before + ["できあがり.pdf"]))
        #expect(try workspace.pageRotations(out) == [0, 90])
    }

    @Test("解除にチェックが無いのにパスワードが要るファイルがあれば、始めずに止まる")
    func lockedWithoutDecrypt() async throws {
        let locked = try workspace.lockedFile()
        let files = [PipelineFile(url: locked, encryption: .passwordRequired, rotation: RotationPlan(pageCount: 0)),
                     PipelineFile(url: workspace.fileB, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 3))]
        await #expect(throws: EngineError.passwordRequired(path: locked.path)) {
            _ = try await pipeline.run(files, steps: [.merge], to: workspace.url("x.pdf")) { _, _ in "user-secret" }
        }
    }

    @Test("何も変わらない指定（回転の指定なしで回転だけ）は「行う操作がありません」")
    func nothingToDo() async throws {
        let files = [PipelineFile(url: workspace.fileA, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 2))]
        let out = workspace.url("x.pdf")
        await #expect(throws: EngineError.nothingToDo) {
            _ = try await pipeline.run(files, steps: [.rotate], to: out) { _, _ in nil }
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }
}

/// パスワードを聞かれた記録と、順に返す答え
@MainActor
final class AskLog {
    struct Call: Equatable {
        let file: URL
        let isRetry: Bool
    }

    private(set) var calls: [Call] = []
    private var answers: [String]

    nonisolated init(answers: [String]) {
        self.answers = answers
    }

    func answer(_ file: URL, _ isRetry: Bool) async -> String? {
        calls.append(Call(file: file, isRetry: isRetry))
        return answers.isEmpty ? nil : answers.removeFirst()
    }
}
