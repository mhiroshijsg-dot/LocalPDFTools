import Foundation
import PDFEngine
import Testing

@Suite("回転")
struct RotateTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    @Test("ページごとに +90°・そのまま・+180°")
    func perPage() async throws {
        var plan = RotationPlan(pageCount: 3)
        plan.rotate(pageIndex: 0, by: 1)
        plan.rotate(pageIndex: 2, by: 2)
        #expect(plan.qpdfArguments() == ["--rotate=+90:1", "--rotate=+180:3"])
        let out = workspace.url("回転.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(workspace.fileB, plan: plan, to: out)
        #expect(try workspace.pageRotations(out) == [90, 0, 180])
    }

    @Test("すでに回っているページに足し算される（90° + 反時計回り 90° → 0°、90° + 90° → 180°）")
    func addsToExistingRotation() async throws {
        var first = RotationPlan(pageCount: 3)
        first.rotateAll(by: 1)
        let once = workspace.url("回転1.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(workspace.fileB, plan: first, to: once)
        var second = RotationPlan(pageCount: 3)
        second.rotate(pageIndex: 0, by: -1)
        second.rotate(pageIndex: 1, by: 1)
        let twice = workspace.url("回転2.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(once, plan: second, to: twice)
        #expect(try workspace.pageRotations(twice) == [0, 180, 90])
    }

    @Test("大きさがほぼ変わらない（差が 15% 未満）")
    func sizeBarelyChanges() async throws {
        var plan = RotationPlan(pageCount: 3)
        plan.rotateAll(by: 1)
        let out = workspace.url("回転-大きさ.pdf")
        let outcome = try await PDFRotator(runner: workspace.qpdf).rotate(workspace.fileB, plan: plan, to: out)
        // MEMO(2026-11-25・by claude): qpdf は書き直すときに構造を少し整えるので、完全に同じ大きさにはならない
        let ratio = Double(outcome.outputBytes) / Double(outcome.inputBytes)
        #expect(abs(ratio - 1) < 0.15, "元 \(outcome.inputBytes) バイト → 新 \(outcome.outputBytes) バイト")
    }

    @Test("制限付きの PDF は暗号化を保ったまま回る（勝手に外さない）")
    func keepsEncryption() async throws {
        var plan = RotationPlan(pageCount: 2)
        plan.rotateAll(by: 1)
        let out = workspace.url("回転-制限付き.pdf")
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(try workspace.restrictedFile(), plan: plan, to: out)
        #expect(try workspace.document(out).isEncrypted)
        #expect(try workspace.pageRotations(out) == [90, 90])
    }
}
