import CoreGraphics
import Foundation

/// PDF の中の画像 1 つ分
public struct PDFImageInfo: Sendable {
    /// 画像の保存の形式
    public enum Encoding: Sendable, Equatable {
        /// JPEG（DCTDecode）。写真やカラーのスキャン
        case jpeg
        /// 可逆の圧縮（FlateDecode）。画面の写しや図など
        case flate
        /// それ以外（白黒スキャンの CCITT・JBIG2、JPEG 2000 など）。名前は qpdf の表記
        case other(String)
    }

    /// 部品の番号（"12 0 R"）
    public let ref: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteCount: Int64
    public let encoding: Encoding
    /// 色の数（灰色 1・RGB 3・CMYK 4）。分からなければ nil
    public let components: Int?
    /// ページ上で一番大きく描かれたときの大きさ（ポイント）。見つからなければ nil
    public let placedSize: CGSize?
    /// 触れない理由（触れるなら nil）
    public let unsupportedReason: String?
    /// 形式としては作り直せるか（ページ上の場所が分からないだけなら true）。灰色にするのは場所が分からなくてもできる
    public let isRewritable: Bool

    /// ページ上の解像度（縦横の低い方）。描かれている場所が分からなければ nil
    public var effectivePPI: Double? {
        guard let size = placedSize, size.width > 0.5, size.height > 0.5 else { return nil }
        return min(Double(pixelWidth) / (size.width / 72), Double(pixelHeight) / (size.height / 72))
    }

    public var isSupported: Bool { unsupportedReason == nil }

    /// 解像度を下げるなら、新しい幅と高さ（下げないなら nil）。目標より 2% 以上細かいものだけ下げる
    public func resampledSize(targetDPI: Int?) -> (width: Int, height: Int)? {
        guard isSupported, let targetDPI, let ppi = effectivePPI, ppi > Double(targetDPI) * 1.02 else { return nil }
        let scale = Double(targetDPI) / ppi
        return (max(1, Int((Double(pixelWidth) * scale).rounded())), max(1, Int((Double(pixelHeight) * scale).rounded())))
    }
}
