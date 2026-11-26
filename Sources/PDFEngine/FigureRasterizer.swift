import CoreGraphics
import Foundation

/// 図（Form XObject）だけを、白い背景のビットマップに描く。
/// 図だけを 1 ページずつ並べた一時 PDF を qpdf で作り（ページの中身 = 図の命令・ページの枠 = 図の枠）、
/// それを Mac 標準の Core Graphics で描く。元の PDF は変えない。
/// MEMO(2026-11-26・by claude): ページを描いて図の部分を切り取る形にしないのは、図の上や下にある本文の文字まで
/// 画像に入ってしまうため。白い背景にするのは、透明のままだと透明度のデータが別に要り、かえって大きくなるため（計画 §6・V3）。
public struct FigureRasterizer {
    let runner: QPDFRunner

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// 一覧に出す縮小表示（長い辺が maxPixels）を作る。一時ファイルはすぐ消す
    public func thumbnails(_ url: URL, figures: [HeavyFigure], maxPixels: Int) async throws -> [String: CGImage] {
        guard !figures.isEmpty else { return [:] }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPDFTools-figures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let table = try await QPDFObjectTable.load(url, runner: runner)
        let document = try await figureDocument(url, table: table, figures: figures, work: work)
        var images: [String: CGImage] = [:]
        for (index, figure) in figures.enumerated() {
            try Task.checkCancellation()
            let longest = max(figure.bbox.width, figure.bbox.height)
            guard longest > 0 else { continue }
            let scale = CGFloat(maxPixels) / longest
            let width = max(1, Int(figure.bbox.width * scale))
            let height = max(1, Int(figure.bbox.height * scale))
            images[figure.id] = render(document, index: index, figure: figure, width: width, height: height)
        }
        return images
    }

    /// 図だけを 1 ページずつ並べた一時 PDF を work に作って開く（ページの順は figures の順）
    func figureDocument(_ input: URL, table: QPDFObjectTable, figures: [HeavyFigure], work: URL) async throws -> CGPDFDocument {
        guard let firstPage = table.pageRefs.first, let rootRef = rootPagesRef(from: firstPage, table: table),
              var root = table.dictionary(rootRef) else {
            throw EngineError.unreadablePDF(path: input.path)
        }
        var nextID = table.objects.keys.compactMap { Int($0.split(separator: " ").first ?? "") }.max() ?? 0
        let maxObjectID = nextID
        var updates: [String: Any] = [:]
        var kids: [String] = []
        for figure in figures {
            nextID += 1
            let pageRef = "\(nextID) 0 R"
            let box = [figure.bbox.minX, figure.bbox.minY, figure.bbox.maxX, figure.bbox.maxY].map { Double($0) }
            // 資源の無い図は、置かれていたページの資源を使う
            let resources: Any = table.streamDictionary(figure.ref)?["/Resources"]
                ?? table.pageResources(table.pageRefs[figure.pageNumber - 1]) ?? [String: Any]()
            updates["obj:" + pageRef] = ["value": [
                "/Type": "/Page", "/Parent": rootRef, "/MediaBox": box, "/CropBox": box, "/Rotate": 0,
                "/Resources": resources, "/Contents": figure.ref,
            ] as [String: Any]]
            kids.append(pageRef)
        }
        root["/Kids"] = kids
        root["/Count"] = kids.count
        updates["obj:" + rootRef] = ["value": root]

        let header: [String: Any] = ["jsonversion": 2, "pushedinheritedpageresources": false,
                                     "calledgetallpages": false, "maxobjectid": maxObjectID]
        let json = work.appendingPathComponent("figures.json")
        try JSONSerialization.data(withJSONObject: ["qpdf": [header, updates]]).write(to: json)
        let output = work.appendingPathComponent("figures.pdf")
        // 一時ファイルなので、編集の制限が付いた PDF でも描けるように暗号化を外して書く（元のファイルは変えない）
        _ = try await runner.runChecked([input.path, output.path, "--update-from-json=" + json.path, "--decrypt"])
        guard let document = CGPDFDocument(output as CFURL), document.numberOfPages == figures.count else {
            throw EngineError.unreadablePDF(path: input.path)
        }
        return document
    }

    /// 一時 PDF の index 番目（0 始まり）の図を、白い背景の width × height ピクセルの RGB 画像に描く
    func render(_ document: CGPDFDocument, index: Int, figure: HeavyFigure, width: Int, height: Int) -> CGImage? {
        guard let page = document.page(at: index + 1), figure.bbox.width > 0, figure.bbox.height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(width) / figure.bbox.width, y: CGFloat(height) / figure.bbox.height)
        context.translateBy(x: -figure.bbox.minX, y: -figure.bbox.minY)
        context.clip(to: figure.bbox)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// ページの木の一番上（/Parent の無い /Pages）
    private func rootPagesRef(from pageRef: String, table: QPDFObjectTable) -> String? {
        var current = table.dictionary(pageRef)?["/Parent"] as? String
        var depth = 0
        while let ref = current, depth < 32 {
            guard let parent = table.dictionary(ref)?["/Parent"] as? String else { return ref }
            current = parent
            depth += 1
        }
        return nil
    }
}
