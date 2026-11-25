import Foundation

/// 読み込んだ PDF の基本情報
public struct PDFFileInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let byteSize: Int64
    public let pageCount: Int
    /// 暗号化されている（開けるが編集・印刷などが制限されているものも含む）
    public let isEncrypted: Bool
    /// しおり（目次）がある
    public let hasOutline: Bool

    public init(url: URL, byteSize: Int64, pageCount: Int, isEncrypted: Bool, hasOutline: Bool) {
        self.id = UUID()
        self.url = url
        self.byteSize = byteSize
        self.pageCount = pageCount
        self.isEncrypted = isEncrypted
        self.hasOutline = hasOutline
    }

    public var fileName: String { url.lastPathComponent }
}
