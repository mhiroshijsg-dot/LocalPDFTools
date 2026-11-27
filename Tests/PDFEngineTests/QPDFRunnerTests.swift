import Foundation
import PDFEngine
import Testing

/// qpdf を呼ぶ部品の、qpdf が普通に終わらなかったときの扱い
@Suite("qpdf の呼び出し")
struct QPDFRunnerTests {

    @Test("途中で落ちたら、終了コードとして返さずに qpdfCrashed にする")
    func crashIsNotAnExitCode() async throws {
        // qpdf の代わりに、自分にシグナルを送って終わるシェルを走らせる（SIGTERM なのでクラッシュレポートは作られない）
        let runner = QPDFRunner(executableURL: URL(fileURLWithPath: "/bin/sh"))
        await #expect(throws: EngineError.qpdfCrashed(signal: SIGTERM)) {
            _ = try await runner.run(["-c", "kill -TERM $$"])
        }
    }

    @Test("普通に終わったら、0 以外の終了コードもそのまま返す")
    func exitCodeIsReturned() async throws {
        let runner = QPDFRunner(executableURL: URL(fileURLWithPath: "/bin/sh"))
        let output = try await runner.run(["-c", "exit 2"])
        #expect(output.exitCode == 2)
        #expect(!output.succeeded)
    }
}
