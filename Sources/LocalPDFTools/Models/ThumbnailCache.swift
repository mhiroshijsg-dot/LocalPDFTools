import AppKit
import Observation
import PDFKit

/// ページの縮小表示を作って覚えておく（同じページを何度も描かない）
@MainActor
@Observable
final class ThumbnailCache {
    private(set) var images: [Int: NSImage] = [:]

    /// まだ無ければ作る。今のページの向き（/Rotate）は反映される
    func load(pageIndex: Int, from document: PDFDocument) {
        guard images[pageIndex] == nil, let page = document.page(at: pageIndex) else { return }
        images[pageIndex] = page.thumbnail(of: CGSize(width: 240, height: 240), for: .mediaBox)
    }

    func removeAll() {
        images = [:]
    }
}
