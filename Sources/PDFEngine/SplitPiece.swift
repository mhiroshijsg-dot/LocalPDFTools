import Foundation

/// 分割してできたファイル 1 つ分
public struct SplitPiece: Sendable, Hashable {
    public let url: URL
    /// 元の PDF のページ番号（1 から）
    public let pages: ClosedRange<Int>
    public let bytes: Int64

    /// 保存する名前: 元の名前_p1-3.pdf（1 ページだけなら 元の名前_p4.pdf）
    public static func fileName(base: String, pages: ClosedRange<Int>) -> String {
        let label = pages.count == 1 ? "\(pages.lowerBound)" : "\(pages.lowerBound)-\(pages.upperBound)"
        return "\(base)_p\(label).pdf"
    }
}
