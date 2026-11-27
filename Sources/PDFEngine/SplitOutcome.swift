import Foundation

/// 分割して保存したときの結果（新しく作ったフォルダと、中に入れたファイル）
public struct SplitOutcome: Sendable {
    /// 新しく作ったフォルダ
    public let folder: URL
    /// 中に入れたファイル（分けた順）
    public let pieces: [SplitPiece]
    /// 元の PDF の大きさ
    public let inputBytes: Int64
    /// qpdf が出した警告（成功はしている）
    public let warnings: [String]
    /// 圧縮もしたときだけ: 全ファイルを合わせた数
    public let compression: CompressionResult?

    public var totalBytes: Int64 { pieces.reduce(0) { $0 + $1.bytes } }
    /// 一番大きいファイル（提出先の上限は 1 ファイルごとに効くので、合計とは別に見せる）
    public var largestBytes: Int64 { pieces.map(\.bytes).max() ?? 0 }
}
