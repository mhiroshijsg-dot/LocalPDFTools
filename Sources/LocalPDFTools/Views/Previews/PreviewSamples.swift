#if DEBUG
import AppKit
import PDFEngine

/// Xcode のプレビュー（右側にその場で描かれる画面）に使う見本のデータ。
/// MEMO(2026-11-25・by claude): 開発用のビルドにだけ入る（#if DEBUG）。配る .app（release）には入らない。
/// ファイル名は架空のもの。実際のファイルは読まない（回転の見本の PDF だけは一時フォルダに合成する）。
/// MEMO(2026-11-26・by claude): 段階 2.5 で画面を作業台 1 つにしたので、見本も作業台の形にした。
@MainActor
enum PreviewSamples {
    /// ファイルを 3 つ並べ、解除と結合にチェックした状態（ファイルは架空。1 つは制限付き・1 つはパスワードが要る）
    static func workspace() -> Workspace {
        let model = Workspace()
        let plain = EncryptionReport(status: .notEncrypted, method: nil, deniedPermissions: [])
        model.files = [
            WorkFile(url: URL(fileURLWithPath: "/見本/成績証明書 大学.pdf"),
                     byteSize: 1_240_000, pageCount: 2, encryption: plain, hasOutline: false),
            WorkFile(url: URL(fileURLWithPath: "/見本/スコアレポート.pdf"), byteSize: 310_000, pageCount: 1,
                     encryption: EncryptionReport(status: .restricted, method: "AES-256",
                                                  deniedPermissions: [.printLow, .printHigh, .extract, .modifyAssembly, .modifyOther]),
                     hasOutline: true),
            WorkFile(url: URL(fileURLWithPath: "/見本/成績証明書 大学院.pdf"), byteSize: 860_000, pageCount: nil,
                     encryption: EncryptionReport(status: .passwordRequired, method: nil, deniedPermissions: nil),
                     hasOutline: false),
        ]
        model.selected = [.decrypt, .merge]
        return model
    }

    /// 見本の PDF を入れて、2 ページ目を右に 90°、3 ページ目を 180° にした状態（回転のシート用）
    static func rotatingWorkspace() -> Workspace {
        let model = Workspace()
        let url = samplePDF()
        let file = WorkFile(url: url, byteSize: 0, pageCount: 3,
                            encryption: EncryptionReport(status: .notEncrypted, method: nil, deniedPermissions: []),
                            hasOutline: false)
        file.rotate(pageIndex: 1, by: 1)
        file.rotate(pageIndex: 2, by: 2)
        model.files = [file]
        model.selected = [.rotate]
        return model
    }

    /// 向きが分かる見本の PDF（縦長・横長・縦長の 3 ページ。大きな番号と上辺の帯入り）を一時フォルダに作る
    static func samplePDF() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LocalPDFTools-preview.pdf")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else { return url }
        let sizes = [CGSize(width: 300, height: 420), CGSize(width: 420, height: 300), CGSize(width: 300, height: 420)]
        for (index, size) in sizes.enumerated() {
            var box = CGRect(origin: .zero, size: size)
            context.beginPage(mediaBox: &box)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(box)
            // 上辺の帯（どちらが上かが分かるように）
            context.setFillColor(NSColor.systemBlue.cgColor)
            context.fill(CGRect(x: 0, y: size.height - 40, width: size.width, height: 40))
            let number = NSAttributedString(string: "\(index + 1)", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 120),
                .foregroundColor: NSColor.darkGray,
            ])
            let line = CTLineCreateWithAttributedString(number)
            context.textPosition = CGPoint(x: size.width / 2 - 35, y: size.height / 2 - 50)
            CTLineDraw(line, context)
            context.endPage()
        }
        context.closePDF()
        return url
    }
}
#endif
