import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 画像 1 つを、解像度を下げたり JPEG の画質を下げたりして作り直す（Mac 標準の画像処理）。
/// 文字やフォントには触れない。元より小さくならなければ作り直さない（nil を返す）。
struct ImageRecompressor {
    /// 作り直した画像。filter が nil なら圧縮していない画素の並び（qpdf が書き出すときに可逆で圧縮する）
    struct Replacement {
        let data: Data
        let width: Int
        let height: Int
        let filter: String?
        let wasResampled: Bool
    }

    /// data は、JPEG なら JPEG のファイルそのもの、可逆の圧縮（Flate）なら圧縮を解いた画素の並び
    func recompress(_ image: PDFImageInfo, data: Data, settings: CompressionSettings) -> Replacement? {
        guard image.isSupported, let components = image.components, components == 1 || components == 3 else { return nil }
        let newSize = image.resampledSize(targetDPI: settings.targetDPI)
        switch image.encoding {
        case .jpeg:
            guard newSize != nil || settings.jpegQuality != nil,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            let width = newSize?.width ?? decoded.width
            let height = newSize?.height ?? decoded.height
            guard let drawn = Self.draw(decoded, width: width, height: height, components: components),
                  let jpeg = Self.jpegData(drawn, quality: newSize == nil ? settings.jpegQuality!.value
                                                                          : settings.qualityForResampled.value),
                  jpeg.count < data.count else { return nil }
            return Replacement(data: jpeg, width: width, height: height, filter: "/DCTDecode", wasResampled: newSize != nil)
        case .flate:
            // 可逆の画像は画質を下げない（文字の写しなどがにじむため）。解像度を下げるときだけ作り直す
            guard let newSize, data.count == image.pixelWidth * image.pixelHeight * components,
                  let decoded = Self.image(fromPixels: data, width: image.pixelWidth, height: image.pixelHeight,
                                           components: components),
                  let drawn = Self.draw(decoded, width: newSize.width, height: newSize.height, components: components),
                  let pixels = Self.pixels(of: drawn, components: components) else { return nil }
            return Replacement(data: pixels, width: newSize.width, height: newSize.height, filter: nil, wasResampled: true)
        case .other:
            return nil
        }
    }

    private static func colorSpace(components: Int) -> CGColorSpace {
        components == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
    }

    /// 指定の大きさに描き直す（灰色は灰色のまま、RGB は RGB のまま）
    private static func draw(_ image: CGImage, width: Int, height: Int, components: Int) -> CGImage? {
        // MEMO(2026-11-26・by claude): 元の画像と同じ色の空間で描けば、色の変換が起きない
        let space = image.colorSpace.flatMap { $0.numberOfComponents == components ? $0 : nil }
            ?? colorSpace(components: components)
        let info = components == 1 ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: components == 1 ? width : width * 4,
                                      space: space, bitmapInfo: info) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func jpegData(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func image(fromPixels data: Data, width: Int, height: Int, components: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8 * components,
                       bytesPerRow: width * components, space: colorSpace(components: components),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// 描き直した画像を、PDF の画素の並び（灰色 1 バイト・RGB 3 バイト、行の間に隙間なし）にする
    private static func pixels(of image: CGImage, components: Int) -> Data? {
        guard let source = image.dataProvider?.data as Data? else { return nil }
        let width = image.width
        let height = image.height
        let rowBytes = image.bytesPerRow
        var result = Data(capacity: width * height * components)
        source.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for row in 0..<height {
                let start = row * rowBytes
                if components == 1 {
                    result.append(contentsOf: buffer[start..<(start + width)])
                } else {
                    for column in 0..<width {
                        let pixel = start + column * 4
                        result.append(contentsOf: buffer[pixel..<(pixel + 3)])
                    }
                }
            }
        }
        return result
    }
}
