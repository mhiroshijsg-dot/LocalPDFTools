import CoreGraphics
import Foundation

/// ページに置かれた図（Form XObject）1 つの情報。画像にしたときの大きさの目安も出す。
public struct HeavyFigure: Identifiable, Equatable, Sendable {
    /// 「重い図」として一覧に出す基準（どちらかを満たせば出す）。村田さんの了承済み（2026-11-26）
    public static let minimumOperations = 5_000
    public static let minimumBytes: Int64 = 100_000
    /// 画像の 1 辺のピクセル数の上限（大きすぎる画像で手間取らないように）
    static let maximumPixels = 8_000
    /// 線画を可逆の圧縮で保存したときの、1 ピクセルあたりのバイト数の目安。
    /// MEMO(2026-11-26・by claude): 色の点を 3 万〜30 万個打った散布図の合成データでの実測は 0.36〜0.62（150〜300 dpi）。
    /// 白い所の多い図ではもっと小さくなるので、間を取った大まかな値にした。
    /// 塗りの多い図では外れるので、画面には必ず「目安」と書き、正確な数字は試算で出す。
    static let estimatedBytesPerPixel = 0.4

    /// 図の中身の指紋。解除・回転・結合で部品の番号が変わっても同じ値になるので、選んだ図をこれで覚える
    public let id: String
    /// 部品の番号（このファイルの中だけで通じる）
    let ref: String
    /// 最初に置かれているページ（1 始まり）
    public let pageNumber: Int
    /// 描く命令の数
    public let operationCount: Int
    /// 線や点の命令のデータの大きさ（図と、図の中の図の命令。画像は含めない）
    public let vectorBytes: Int64
    /// 今の大きさ（図の命令と、図の中の図・画像のデータの合計。フォントは本文と共有することがあるので含めない）
    public let byteCount: Int64
    /// ページ上に置かれた大きさ（ポイント）
    public let placedSize: CGSize
    /// 図の枠（図の中の座標）
    let bbox: CGRect
    /// 図の中の 1 単位が、ページ上で何ポイントになるか
    let scaleX: CGFloat
    let scaleY: CGFloat
    /// 図の中にある図・画像の部品の番号（画像にすると使われなくなる）
    let nestedRefs: Set<String>

    /// 重い図か（一覧に出すか）。大きさは線や点の命令の分だけで見る（中の画像は「画像の縮小」で小さくするもので、
    /// すでに画像だけの図を一覧に出しても意味が無いため）
    public var isHeavy: Bool {
        operationCount >= Self.minimumOperations || vectorBytes >= Self.minimumBytes
    }

    /// 指定の dpi で画像にしたときのピクセル数（ページ上に置かれた一番大きい大きさに対して計算する）
    public func pixelSize(dpi: Int) -> (width: Int, height: Int) {
        let factor = CGFloat(dpi) / 72
        let width = Int((bbox.width * scaleX * factor).rounded(.up))
        let height = Int((bbox.height * scaleY * factor).rounded(.up))
        return (min(max(width, 1), Self.maximumPixels), min(max(height, 1), Self.maximumPixels))
    }

    /// 画像にしたときの大きさの目安（式による見積もり。実際には変換しない）
    public func estimatedBytes(dpi: Int) -> Int64 {
        let size = pixelSize(dpi: dpi)
        return Int64(Double(size.width * size.height) * Self.estimatedBytesPerPixel)
    }

    /// 画像にすると小さくなる見込みがあるか（目安が今の 9 割を下回るか）
    public func isEffective(dpi: Int) -> Bool {
        estimatedBytes(dpi: dpi) * 10 < byteCount * 9
    }
}
