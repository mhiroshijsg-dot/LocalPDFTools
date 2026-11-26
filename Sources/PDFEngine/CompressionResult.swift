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
    /// 外した要らないデータ（編集用のデータ・縮小画像・画像などに付いた説明のデータ）の数
    public var removedExtras = 0
    /// 1 つにまとめた重複の部品の数（残した方は数えない）
    public var mergedDuplicates = 0
    /// 色の無い RGB の画像を灰色にした数
    public var grayImages = 0
    /// Type1 から CFF に作り直したフォントの数
    public var convertedFonts = 0
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
        sum.removedExtras += rhs.removedExtras
        sum.mergedDuplicates += rhs.mergedDuplicates
        sum.grayImages += rhs.grayImages
        sum.convertedFonts += rhs.convertedFonts
        sum.warnings += rhs.warnings
        return sum
    }
}
