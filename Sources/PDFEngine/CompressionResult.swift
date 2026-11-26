/// 1 つの PDF を圧縮した結果の数
public struct CompressionResult: Sendable {
    /// 解像度を下げた画像の数
    public var resampledImages = 0
    /// 解像度は変えずに JPEG の画質だけ下げた画像の数
    public var requalifiedImages = 0
    /// 作り直しても小さくならなかったので、元のまま残した画像の数
    public var keptImages = 0
    /// 図の線を減らした数（消した線・間引いた点）
    public var vector = VectorThinningReport()
    /// 画像にした図の数
    public var flattenedFigures = 0
    /// 画像にしても小さくならなかったので、元のまま残した図の数
    public var keptFigures = 0
    /// qpdf の警告
    public var warnings: [String] = []

    public init() {}

    public static func + (lhs: CompressionResult, rhs: CompressionResult) -> CompressionResult {
        var sum = lhs
        sum.resampledImages += rhs.resampledImages
        sum.requalifiedImages += rhs.requalifiedImages
        sum.keptImages += rhs.keptImages
        sum.vector = sum.vector + rhs.vector
        sum.flattenedFigures += rhs.flattenedFigures
        sum.keptFigures += rhs.keptFigures
        sum.warnings += rhs.warnings
        return sum
    }
}
