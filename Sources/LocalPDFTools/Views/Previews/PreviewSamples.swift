#if DEBUG
import AppKit
import PDFEngine

/// Xcode のプレビュー（右側にその場で描かれる画面）に使う見本のデータ。
/// MEMO(2026-11-25・by claude): 開発用のビルドにだけ入る（#if DEBUG）。配る .app（release）には入らない。
/// ファイル名は架空のもの。実際のファイルは読まない（回転の見本の PDF だけは一時フォルダに合成する）。
@MainActor
enum PreviewSamples {
    /// ファイルを 3 つ並べた結合の状態（1 つは制限付き・1 つはしおり付き）
    static func mergeModel() -> MergeModel {
        let model = MergeModel()
        model.files = [
            PDFFileInfo(url: URL(fileURLWithPath: "/見本/成績証明書 大学.pdf"),
                        byteSize: 1_240_000, pageCount: 2, isEncrypted: false, hasOutline: false),
            PDFFileInfo(url: URL(fileURLWithPath: "/見本/成績証明書 大学院.pdf"),
                        byteSize: 860_000, pageCount: 3, isEncrypted: false, hasOutline: false),
            PDFFileInfo(url: URL(fileURLWithPath: "/見本/スコアレポート.pdf"),
                        byteSize: 310_000, pageCount: 1, isEncrypted: true, hasOutline: true),
        ]
        return model
    }

    /// 見本の PDF を開いて、2 ページ目を右に 90°、3 ページ目を 180° にした回転の状態
    static func rotateModel() -> RotateModel {
        let model = RotateModel()
        model.load([samplePDF()])
        model.rotate(pageIndex: 1, by: 1)
        model.rotate(pageIndex: 2, by: 2)
        return model
    }

    /// 暗号化の解除の状態（ファイルは架空。ETS 型の制限付き、またはパスワードが要るもの）
    static func encryptionModel(_ status: EncryptionReport.Status) -> EncryptionModel {
        let model = EncryptionModel()
        let report: EncryptionReport
        switch status {
        case .passwordRequired:
            report = EncryptionReport(status: .passwordRequired, method: nil, deniedPermissions: nil)
        default:
            report = EncryptionReport(status: .restricted, method: "AES-256",
                                      deniedPermissions: [.printLow, .printHigh, .extract, .modifyAssembly, .modifyOther])
        }
        model.show(report, for: URL(fileURLWithPath: "/見本/スコアレポート.pdf"))
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
