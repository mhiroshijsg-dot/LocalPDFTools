import Foundation
import PDFKit

/// PDF を開いて基本情報を読む（中身は変えない）
public struct PDFInspector {
    public init() {}

    public func inspect(_ url: URL) throws -> PDFFileInfo {
        guard let document = PDFDocument(url: url) else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        if document.isLocked {
            throw EngineError.passwordRequired(path: url.path)
        }
        let outlineCount = document.outlineRoot?.numberOfChildren ?? 0
        return PDFFileInfo(url: url,
                           byteSize: FileSize.of(url) ?? 0,
                           pageCount: document.pageCount,
                           isEncrypted: document.isEncrypted,
                           hasOutline: outlineCount > 0)
    }
}
