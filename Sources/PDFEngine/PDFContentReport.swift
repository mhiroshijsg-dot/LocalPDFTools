import Foundation

/// PDF の大きさの内訳（圧縮の画面に出す）
public struct PDFContentReport: Sendable {
    public let totalBytes: Int64
    public let images: [PDFImageInfo]
    public let fontBytes: Int64

    public var imageBytes: Int64 { images.reduce(0) { $0 + $1.byteCount } }
    /// 画像とフォント以外（文字や線の描画・構造など）
    public var otherBytes: Int64 { max(0, totalBytes - imageBytes - fontBytes) }

    /// 解像度を下げる画像の数
    public func resampledCount(targetDPI: Int?) -> Int {
        images.filter { $0.resampledSize(targetDPI: targetDPI) != nil }.count
    }

    /// 触れない画像の理由ごとの数（例: 「白黒スキャン（CCITT）: 2」）
    public var unsupportedSummary: [(reason: String, count: Int)] {
        var counts: [String: Int] = [:]
        for image in images {
            if let reason = image.unsupportedReason { counts[reason, default: 0] += 1 }
        }
        return counts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// 圧縮した後の大きさの目安（実際に変換はしない。式による見積もり）。
    /// 構造の圧縮で小さくなる分は数えない（変わらないものとして足す）
    public func estimatedBytes(_ settings: CompressionSettings) -> Int64 {
        var bytes = totalBytes - imageBytes
        for image in images {
            bytes += Self.estimatedBytes(image, settings)
        }
        return bytes
    }

    static func estimatedBytes(_ image: PDFImageInfo, _ settings: CompressionSettings) -> Int64 {
        guard image.isSupported else { return image.byteCount }
        var ratio = 1.0
        if let size = image.resampledSize(targetDPI: settings.targetDPI) {
            ratio = Double(size.width * size.height) / Double(image.pixelWidth * image.pixelHeight)
            if image.encoding == .jpeg { ratio *= settings.qualityForResampled.estimatedRatio }
        } else if image.encoding == .jpeg, let quality = settings.jpegQuality {
            ratio = quality.estimatedRatio
        }
        // 元より大きくなる画像は差し替えないので、上限は元の大きさ
        return min(image.byteCount, Int64(Double(image.byteCount) * ratio))
    }
}
