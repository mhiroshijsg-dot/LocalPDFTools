import Foundation
import PDFEngine
import Testing

@Suite("分割")
struct SplitTests {
    let workspace: TestWorkspace
    /// 5 ページ。幅を 300・310・320・330・340 と変えて、どのページが入ったかを幅で見分ける
    let fivePages: URL
    /// 保存先に選ぶ場所（入力とは別のフォルダ）
    let parent: URL

    init() throws {
        workspace = try TestWorkspace()
        fivePages = try workspace.factory.make(name: "五ページ.pdf",
                                               pageSizes: (0..<5).map { CGSize(width: 300 + $0 * 10, height: 400) })
        parent = workspace.url("保存先")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    var pipeline: PDFPipeline { PDFPipeline(runner: workspace.qpdf) }

    func neverAsked(_ file: URL, _ isRetry: Bool) async -> String? {
        Issue.record("パスワードの要らない PDF でパスワードを聞いた")
        return nil
    }

    /// 分けたファイルごとのページの幅
    func widths(_ outcome: SplitOutcome) throws -> [[CGFloat]] {
        try outcome.pieces.map { try workspace.pageWidths($0.url) }
    }

    // MARK: 範囲の読み方

    @Test("書いた範囲を読む（「8-」は最後まで・全角・読点・空白入り）")
    func parseRanges() throws {
        #expect(try PageRangeParser.parse("1-3, 5, 8-", pageCount: 10) == [1...3, 5...5, 8...10])
        #expect(try PageRangeParser.parse("１－３、５", pageCount: 10) == [1...3, 5...5])
        #expect(try PageRangeParser.parse("1 - 3  4〜6\n7", pageCount: 10) == [1...3, 4...6, 7...7])
        #expect(try PageRangeParser.parse("2-3, 2-3", pageCount: 3) == [2...3, 2...3])
    }

    @Test("読めない・ページの外の範囲はエラー", arguments: ["", "0", "11", "5-3", "abc", "1-2-3", "-3"])
    func rejectRanges(_ text: String) {
        #expect(throws: EngineError.self) { try PageRangeParser.parse(text, pageCount: 10) }
    }

    @Test("分け方をページの範囲にする")
    func planRanges() throws {
        #expect(try SplitPlan.eachPage.ranges(pageCount: 3) == [1...1, 2...2, 3...3])
        #expect(try SplitPlan.everyPages(2).ranges(pageCount: 5) == [1...2, 3...4, 5...5])
        #expect(try SplitPlan.everyPages(9).ranges(pageCount: 5) == [1...5])
        #expect(try SplitPlan.cuts([4, 2]).ranges(pageCount: 5) == [1...2, 3...4, 5...5])
        // 最後のページの後・0 は切れ目にならない
        #expect(try SplitPlan.cuts([5, 0]).ranges(pageCount: 5) == [1...5])
        #expect(throws: EngineError.self) { try SplitPlan.everyPages(0).ranges(pageCount: 5) }
    }

    @Test("同じ大きさで先頭から区切った形かを見分ける")
    func uniformChunks() {
        #expect(SplitPlan.uniformChunkSize(of: [1...2, 3...4, 5...5], pageCount: 5) == 2)
        #expect(SplitPlan.uniformChunkSize(of: [1...2, 3...5], pageCount: 5) == nil)
        #expect(SplitPlan.uniformChunkSize(of: [1...2, 3...4], pageCount: 5) == nil)
    }

    @Test("名前は 元の名前_p1-3.pdf・1 ページなら 元の名前_p4.pdf")
    func pieceNames() {
        #expect(SplitPiece.fileName(base: "成績", pages: 1...3) == "成績_p1-3.pdf")
        #expect(SplitPiece.fileName(base: "成績", pages: 4...4) == "成績_p4.pdf")
    }

    // MARK: 分けて保存する

    @Test("1 ページずつ: 新しいフォルダに 5 つ・ページは元の順・入力は変わらない・途中のファイルは残らない")
    func eachPage() async throws {
        let before = try workspace.sha(fivePages)
        let outcome = try await pipeline.runSplit(
            PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
            steps: [.split], split: .eachPage, baseName: "五ページ", folderName: "五ページ_split",
            in: parent, askPassword: neverAsked)

        #expect(outcome.folder == parent.appendingPathComponent("五ページ_split", isDirectory: true))
        #expect(outcome.pieces.map(\.url.lastPathComponent)
                == ["五ページ_p1.pdf", "五ページ_p2.pdf", "五ページ_p3.pdf", "五ページ_p4.pdf", "五ページ_p5.pdf"])
        #expect(try widths(outcome) == [[300], [310], [320], [330], [340]])
        #expect(try workspace.sha(fivePages) == before)
        // 保存先には新しいフォルダだけ・フォルダの中には分けたファイルだけ
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path) == ["五ページ_split"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: outcome.folder.path).sorted()
                == outcome.pieces.map(\.url.lastPathComponent).sorted())
        #expect(outcome.pieces.allSatisfy { $0.bytes > 0 })
        #expect(outcome.largestBytes == outcome.pieces.map(\.bytes).max())
    }

    @Test("N ページごと（qpdf でまとめて分ける）と、同じ範囲を書いたとき（1 つずつ分ける）が同じ")
    func uniformMatchesRanges() async throws {
        let file = PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5))
        let every = try await pipeline.runSplit(file, steps: [.split], split: .everyPages(2), baseName: "a",
                                                folderName: "every", in: parent, askPassword: neverAsked)
        let written = try await pipeline.runSplit(file, steps: [.split], split: .ranges("1-2, 3-4, 5"), baseName: "a",
                                                  folderName: "written", in: parent, askPassword: neverAsked)
        #expect(try widths(every) == [[300, 310], [320, 330], [340]])
        #expect(try widths(every) == widths(written))
        #expect(every.pieces.map(\.url.lastPathComponent) == ["a_p1-2.pdf", "a_p3-4.pdf", "a_p5.pdf"])
        #expect(every.pieces.map(\.pages) == [1...2, 3...4, 5...5])
    }

    @Test("書いた順に作る・重なる範囲や同じ範囲もそのまま（同じ名前には _2 を付ける）")
    func writtenOrder() async throws {
        let outcome = try await pipeline.runSplit(
            PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
            steps: [.split], split: .ranges("4-5, 1-2, 2, 2"), baseName: "a", folderName: "out",
            in: parent, askPassword: neverAsked)
        #expect(try widths(outcome) == [[330, 340], [300, 310], [310], [310]])
        #expect(outcome.pieces.map(\.url.lastPathComponent) == ["a_p4-5.pdf", "a_p1-2.pdf", "a_p2.pdf", "a_p2_2.pdf"])
    }

    @Test("同じ名前のフォルダが既にあれば「名前 2」にする（既にあるフォルダの中身は変えない）")
    func existingFolder() async throws {
        let existing = parent.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let keep = existing.appendingPathComponent("a_p1.pdf")
        try Data("前からあるファイル".utf8).write(to: keep)

        let outcome = try await pipeline.runSplit(
            PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
            steps: [.split], split: .eachPage, baseName: "a", folderName: "out", in: parent, askPassword: neverAsked)
        #expect(outcome.folder.lastPathComponent == "out 2")
        #expect(try String(contentsOf: keep, encoding: .utf8) == "前からあるファイル")
        #expect(try FileManager.default.contentsOfDirectory(atPath: existing.path) == ["a_p1.pdf"])
    }

    @Test("範囲が読めなければ、保存先に何も作らない")
    func invalidRangeLeavesNothing() async throws {
        await #expect(throws: EngineError.self) {
            try await pipeline.runSplit(
                PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
                steps: [.split], split: .ranges("3-9"), baseName: "a", folderName: "out", in: parent,
                askPassword: neverAsked)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    }

    @Test("分けた後に回しても、分ける前に回したのと同じ（元のページ番号で当てる）")
    func rotateAfterSplit() async throws {
        var plan = RotationPlan(pageCount: 5)
        plan.rotate(pageIndex: 3, by: 1)  // 4 ページ目を右に 90°
        let file = PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: plan)
        let first = try await pipeline.runSplit(file, steps: [.rotate, .split], split: .cuts([2]), baseName: "a",
                                                folderName: "回転が先", in: parent, askPassword: neverAsked)
        let later = try await pipeline.runSplit(file, steps: [.split, .rotate], split: .cuts([2]), baseName: "a",
                                                folderName: "分割が先", in: parent, askPassword: neverAsked)
        let rotations = try later.pieces.map { try workspace.pageRotations($0.url) }
        #expect(rotations == [[0, 0], [0, 90, 0]])
        #expect(try first.pieces.map { try workspace.pageRotations($0.url) } == rotations)
    }

    @Test("制限付きの PDF: 解除なしで分けても、できる PDF に制限は残らない（結合と同じ。画面で先に確認する）")
    func restrictedLosesProtection() async throws {
        let restricted = try workspace.restrictedFile()
        let outcome = try await pipeline.runSplit(
            PipelineFile(url: restricted, encryption: .restricted, rotation: RotationPlan(pageCount: 2)),
            steps: [.split], split: .eachPage, baseName: "a", folderName: "out", in: parent, askPassword: neverAsked)
        #expect(outcome.pieces.count == 2)
        for piece in outcome.pieces {
            #expect(try await PDFEncryptionInspector(runner: workspace.qpdf).inspect(piece.url).status == .notEncrypted)
        }
    }

    @Test("パスワードが要る PDF: 解除なしでは分けない・解除ありなら聞いて分ける")
    func lockedFile() async throws {
        let locked = try workspace.lockedFile()
        let file = PipelineFile(url: locked, encryption: .passwordRequired, rotation: RotationPlan(pageCount: 0))
        await #expect(throws: EngineError.passwordRequired(path: locked.path)) {
            try await pipeline.runSplit(file, steps: [.split], split: .eachPage, baseName: "a", folderName: "out",
                                        in: parent, askPassword: neverAsked)
        }
        let asked = AskLog(answers: ["user-secret"])
        let outcome = try await pipeline.runSplit(file, steps: [.decrypt, .split], split: .eachPage, baseName: "a",
                                                  folderName: "out", in: parent, askPassword: asked.answer)
        #expect(await asked.calls.count == 1)
        #expect(try widths(outcome) == [[300], [300]])
        for piece in outcome.pieces {
            #expect(try await PDFEncryptionInspector(runner: workspace.qpdf).inspect(piece.url).status == .notEncrypted)
        }
    }

    @Test("分けた後に圧縮: 分けたファイルごとに圧縮し、数は合わせて返す")
    func compressAfterSplit() async throws {
        let outcome = try await pipeline.runSplit(
            PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
            steps: [.split, .compress], split: .cuts([3]), baseName: "a", folderName: "out", in: parent,
            askPassword: neverAsked)
        #expect(try widths(outcome) == [[300, 310, 320], [330, 340]])
        #expect(outcome.compression != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: outcome.folder.path).count == 2)
    }

    @Test("結合と一緒には行わない")
    func notWithMerge() async throws {
        await #expect(throws: EngineError.nothingToDo) {
            try await pipeline.runSplit(
                PipelineFile(url: fivePages, encryption: .notEncrypted, rotation: RotationPlan(pageCount: 5)),
                steps: [.merge, .split], split: .eachPage, baseName: "a", folderName: "out", in: parent,
                askPassword: neverAsked)
        }
    }
}
