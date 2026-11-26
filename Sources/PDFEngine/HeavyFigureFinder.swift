import CoreGraphics
import Foundation

/// PDF の中の図（ページに置かれた Form XObject）を探して、描く命令の数と大きさを数える。中身は変えない。
/// 描画の命令を読むだけで、図を描いたり画像にしたりはしない。
public struct HeavyFigureFinder {
    let runner: QPDFRunner

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    public func find(_ url: URL) async throws -> FigureReport {
        try find(url, table: try await QPDFObjectTable.load(url, runner: runner))
    }

    /// 部品の一覧をすでに読んであるとき
    func find(_ url: URL, table: QPDFObjectTable) throws -> FigureReport {
        guard let document = CGPDFDocument(url as CFURL), document.isUnlocked else {
            throw EngineError.passwordRequired(path: url.path)
        }
        let scanner = FigureScanner(table: table)
        scanner.scan(document)
        func bytes(_ refs: Set<String>) -> Int64 {
            refs.reduce(Int64(0)) { $0 + Int64(table.number(table.streamDictionary($1)?["/Length"]) ?? 0) }
        }
        let figures = scanner.figures.map { figure in
            let vectorBytes = bytes(figure.nestedForms.union([figure.ref]))
            return HeavyFigure(id: figure.contentHash, ref: figure.ref, pageNumber: figure.pageIndex + 1,
                               operationCount: figure.operationCount, vectorBytes: vectorBytes,
                               byteCount: vectorBytes + bytes(figure.nestedImages), placedSize: figure.placedSize,
                               bbox: figure.bbox, scaleX: figure.scaleX, scaleY: figure.scaleY,
                               nestedRefs: figure.nestedForms.union(figure.nestedImages))
        }
        let heavyPages = scanner.pageOperationCounts.enumerated()
            .filter { $0.element >= HeavyFigure.minimumOperations }
            .map { $0.offset + 1 }
        return FigureReport(figures: figures, heavyPages: heavyPages)
    }
}
