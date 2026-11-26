import CoreGraphics
import Foundation
import PDFEngine
import Testing

@Suite("文字の抽出と OCR")
struct TextExtractionTests {
    let workspace: TestWorkspace
    init() throws { workspace = try TestWorkspace() }

    var extractor: PDFTextExtractor { PDFTextExtractor(runner: workspace.qpdf) }
    let lines = ["Transcript of Records", "成績証明書", "GPA 3.85"]

    /// パスワードを聞かれたら困る場面で使う
    let noPassword: PDFPipeline.PasswordProvider = { _, _ in
        Issue.record("パスワードを聞かれた")
        return nil
    }

    @Test("文字の層があるページは、日本語も英語もそのまま取り出す")
    func textLayer() async throws {
        let url = try workspace.factory.makeWithText(name: "文字.pdf", pages: [lines, ["Page two"]])
        let pages = try await extractor.readTextLayer(url, askPassword: noPassword)
        #expect(pages.map(\.source) == [.textLayer, .textLayer])
        for line in lines { #expect(pages[0].text.contains(line)) }
        #expect(pages[1].text.contains("Page two"))
    }

    @Test("文字の層が無いページ（図形だけ・スキャン）は .none で、勝手に OCR しない")
    func noLayer() async throws {
        let scanned = try workspace.factory.makeScanned(name: "スキャン.pdf", lines: lines)
        #expect(try await extractor.readTextLayer(workspace.fileA, askPassword: noPassword).map(\.source) == [.none, .none])
        let pages = try await extractor.readTextLayer(scanned, askPassword: noPassword)
        #expect(pages.map(\.source) == [.none])
        #expect(pages[0].text.isEmpty)
    }

    @Test("スキャンしたページを OCR すると、日本語と英語が行の順に読める・元のファイルは変わらない")
    func ocr() async throws {
        let scanned = try workspace.factory.makeScanned(name: "スキャン.pdf", lines: lines)
        let before = try workspace.sha(scanned)
        let text = try await recognize(scanned, quarterTurns: [])
        let found = text.components(separatedBy: "\n")
        #expect(found.count == 3, "読めた文字: \(text)")
        #expect(found.first?.contains("Transcript") == true)
        #expect(text.contains("成績証明書"))
        #expect(text.contains("3.85"))
        #expect(try workspace.sha(scanned) == before)
    }

    @Test("ページの向き（/Rotate）と作業台の回転の指定を足して、正しい向きにしてから読む")
    func ocrWithRotation() async throws {
        let scanned = try workspace.factory.makeScanned(name: "スキャン.pdf", lines: lines)
        // /Rotate 90（横倒し）にした PDF を、作業台で左に 90°（= 右に 270°）回す指定 → 合わせて元の向き
        let rotated = workspace.url("横倒し.pdf")
        var plan = RotationPlan(pageCount: 1)
        plan.rotate(pageIndex: 0, by: 1)
        _ = try await PDFRotator(runner: workspace.qpdf).rotate(scanned, plan: plan, to: rotated)
        let text = try await recognize(rotated, quarterTurns: [3])
        #expect(text.contains("Transcript"), "読めた文字: \(text)")
        #expect(text.contains("成績証明書"))
    }

    @Test("画像にするときの向きと大きさ（72 dpi・縦長 300×400 を右に 90° → 400×300）")
    func renderSize() throws {
        let document = try #require(CGPDFDocument(workspace.fileA as CFURL))
        let page = try #require(document.page(at: 1))
        let renderer = PageImageRenderer(dpi: 72)
        let upright = try #require(renderer.render(page))
        #expect((upright.width, upright.height) == (300, 400))
        let turned = try #require(renderer.render(page, extraQuarterTurns: 1))
        #expect((turned.width, turned.height) == (400, 300))
        // 長い辺の上限
        let capped = try #require(PageImageRenderer(dpi: 300, maxPixels: 1000).render(page))
        #expect(max(capped.width, capped.height) == 1000)
    }

    @Test("パスワードが要る PDF は、違っていたら聞き直し、合えば読める（日本語のパスワード）")
    func lockedFile() async throws {
        let plain = try workspace.factory.makeWithText(name: "文字.pdf", pages: [lines])
        let locked = try workspace.factory.encrypt(plain, name: "要パスワード.pdf", userPassword: "パスワード",
                                                   qpdf: workspace.qpdf.executableURL)
        var asked: [Bool] = []
        let pages = try await extractor.readTextLayer(locked) { _, isRetry in
            asked.append(isRetry)
            // 3 回目まで聞かれたら、正しいパスワードで開けていない（無限に聞き直さないようにやめる）
            switch asked.count {
            case 1: return "違う"
            case 2: return "パスワード"
            default: return nil
            }
        }
        #expect(asked == [false, true])
        #expect(pages[0].text.contains("成績証明書"))
    }

    @Test("コピーが禁止された PDF（ETS のスコアレポート型）でも、文字の層を読める")
    func copyRestricted() async throws {
        let plain = try workspace.factory.makeWithText(name: "文字.pdf", pages: [lines])
        let restricted = try workspace.factory.encrypt(plain, name: "コピー禁止.pdf", userPassword: "",
                                                       qpdf: workspace.qpdf.executableURL)
        let pages = try await extractor.readTextLayer(restricted, askPassword: noPassword)
        #expect(pages.map(\.source) == [.textLayer])
        #expect(pages[0].text.contains("成績証明書"))
    }

    @Test("パスワードの入力をやめたら読まない")
    func passwordCancelled() async throws {
        let locked = try workspace.lockedFile()
        await #expect(throws: EngineError.passwordCancelled(path: locked.path)) {
            _ = try await extractor.readTextLayer(locked) { _, _ in nil }
        }
    }

    @Test("同じ高さの塊を 1 行にまとめ、左から並べる（表の列の順番が崩れない）")
    func assembleLines() {
        // Vision が返しそうな、ばらばらの順番。2 行目の「3.85」は少しだけ下にずれている
        let blocks = [
            RecognizedBlock(text: "3.85", box: CGRect(x: 0.6, y: 0.68, width: 0.1, height: 0.05)),
            RecognizedBlock(text: "名前", box: CGRect(x: 0.1, y: 0.8, width: 0.1, height: 0.05)),
            RecognizedBlock(text: "GPA", box: CGRect(x: 0.1, y: 0.7, width: 0.1, height: 0.05)),
            RecognizedBlock(text: "山田", box: CGRect(x: 0.6, y: 0.8, width: 0.1, height: 0.05)),
        ]
        #expect(OCRLineAssembler().assemble(blocks) == "名前 山田\nGPA 3.85")
    }

    @Test(".txt: ページの見出し・OCR の印・文字の無いページや読んでいないファイルも黙って空にしない")
    func exportFormat() {
        let pages = [
            PageText(pageIndex: 0, source: .textLayer, text: "一枚目\n"),
            PageText(pageIndex: 1, source: .ocr, text: "二枚目"),
            PageText(pageIndex: 2, source: .none, text: ""),
            PageText(pageIndex: 3, source: .ocr, text: ""),
        ]
        let formatter = TextExportFormatter()
        let single = formatter.format([.init(name: "A.pdf", pages: pages)])
        #expect(single == """
        --- 1 ページ ---
        一枚目

        --- 2 ページ（OCR） ---
        二枚目

        --- 3 ページ ---
        （文字の層なし・OCR していません）

        --- 4 ページ（OCR） ---
        （OCR で文字が見つかりませんでした）

        """)
        let both = formatter.format([.init(name: "A.pdf", pages: [pages[0]]), .init(name: "B.pdf", pages: nil)])
        #expect(both.hasPrefix("===== A.pdf =====\n\n--- 1 ページ ---\n一枚目\n"))
        #expect(both.contains("===== B.pdf =====\n\n（パスワードが要るため、文字を読んでいません）"))
    }

    /// 1 ページ目を OCR した文字
    private func recognize(_ url: URL, quarterTurns: [Int]) async throws -> String {
        var result: [PageText] = []
        try await extractor.recognize(url, pageIndexes: [0], quarterTurns: quarterTurns, askPassword: noPassword) {
            result.append($0)
        }
        #expect(result.map(\.source) == [.ocr])
        return result.first?.text ?? ""
    }
}
