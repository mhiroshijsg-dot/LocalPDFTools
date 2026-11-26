/// 圧縮のやり方
public struct CompressionSettings: Equatable, Sendable {
    /// 選べる解像度（dpi）
    public static let dpiChoices = [300, 200, 150, 100, 72]

    /// 構造の圧縮（小さな部品をまとめて圧縮・データの圧縮し直し）。見た目は一切変わらない
    public var structural: Bool
    /// 画像の解像度をこの dpi まで下げる（nil は変えない）。これより低い画像には触らない
    public var targetDPI: Int?
    /// JPEG の画像を、この画質で保存し直す（nil は変えない。ただし解像度を下げた画像は「高」で保存する）
    public var jpegQuality: JPEGQuality?
    /// 図の線を減らす（既定はすべてオフ）
    public var vector: VectorThinning

    public init(structural: Bool = true, targetDPI: Int? = nil, jpegQuality: JPEGQuality? = nil,
                vector: VectorThinning = VectorThinning()) {
        self.structural = structural
        self.targetDPI = targetDPI
        self.jpegQuality = jpegQuality
        self.vector = vector
    }

    /// 解像度を下げた画像を保存するときの画質
    var qualityForResampled: JPEGQuality { jpegQuality ?? .high }

    /// 画像に触るか
    var touchesImages: Bool { targetDPI != nil || jpegQuality != nil }
}
