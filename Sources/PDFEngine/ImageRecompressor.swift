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
        /// 色の無い RGB の画像を、灰色（1 画素 1 色）にしたか
        let madeGray: Bool
    }

    /// data は、JPEG なら JPEG のファイルそのもの、可逆の圧縮（Flate）なら圧縮を解いた画素の並び。
    /// 解像度・画質の指定が無くても、色の無い RGB の画像は灰色にして保存し直す（圧縮のときにいつも行う。ColorlessPixels）
    func recompress(_ image: PDFImageInfo, data: Data, settings: CompressionSettings) -> Replacement? {
        guard image.isRewritable, let components = image.components, components == 1 || components == 3 else { return nil }
        let newSize = image.resampledSize(targetDPI: settings.targetDPI)
        switch image.encoding {
        case .jpeg:
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            var picture = decoded
            var outComponents = components
            if components == 3, let gray = Self.grayIfColorless(decoded) {
                picture = gray
                outComponents = 1
            }
            let madeGray = outComponents != components
            guard newSize != nil || settings.jpegQuality != nil || madeGray else { return nil }
            let width = newSize?.width ?? decoded.width
            let height = newSize?.height ?? decoded.height
            // 灰色にしただけのときは「高」で保存する（指定があればその画質）
            let quality = newSize == nil ? (settings.jpegQuality ?? .high) : settings.qualityForResampled
            // MEMO(2026-11-26・by claude): JPEG は灰色の画像の色の分をもともと小さく持つので、灰色にしても数 % しか減らないことが多い
            // （合成した A4・300 dpi のスキャンで 2〜11%）。保存し直すたびに画質は少し落ちるので、
            // 灰色にするだけのときは 1 割以上小さくなるときだけ置き換える
            let onlyGray = newSize == nil && settings.jpegQuality == nil
            let limit = onlyGray ? data.count * 9 / 10 : data.count
            guard let drawn = Self.draw(picture, width: width, height: height, components: outComponents),
                  let jpeg = Self.jpegData(drawn, quality: quality.value),
                  jpeg.count < limit else { return nil }
            return Replacement(data: jpeg, width: width, height: height, filter: "/DCTDecode",
                               wasResampled: newSize != nil, madeGray: madeGray)
        case .flate:
            // 可逆の画像は画質を下げない（文字の写しなどがにじむため）。解像度を下げるときと、灰色にできるときだけ作り直す
            guard data.count == image.pixelWidth * image.pixelHeight * components else { return nil }
            var pixels = data
            var outComponents = components
            // 可逆の画像は、R・G・B がすべての画素でぴったり同じときだけ灰色にする（画素の値は変わらない）
            if components == 3, ColorlessPixels.isExactlyGray(rgb: data) {
                pixels = Self.firstChannel(ofRGB: data)
                outComponents = 1
            }
            let madeGray = outComponents != components
            guard newSize != nil || madeGray else { return nil }
            guard let newSize else {
                return Replacement(data: pixels, width: image.pixelWidth, height: image.pixelHeight, filter: nil,
                                   wasResampled: false, madeGray: true)
            }
            guard let decoded = Self.image(fromPixels: pixels, width: image.pixelWidth, height: image.pixelHeight,
                                           components: outComponents),
                  let drawn = Self.draw(decoded, width: newSize.width, height: newSize.height, components: outComponents),
                  let resampled = Self.pixels(of: drawn, components: outComponents) else { return nil }
            return Replacement(data: resampled, width: newSize.width, height: newSize.height, filter: nil,
                               wasResampled: true, madeGray: madeGray)
        case .other:
            return nil
        }
    }

    /// RGB の画素の並びから R だけを取り出す（R・G・B が同じ画像を灰色の並びにする）
    private static func firstChannel(ofRGB data: Data) -> Data {
        var gray = Data(count: data.count / 3)
        gray.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
            data.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                for index in 0..<output.count { output[index] = input[index * 3] }
            }
        }
        return gray
    }

    /// 色の無い画像なら、灰色の画像にして返す（色が付いていれば nil）。
    /// 灰色の値は R・G・B の平均。色の空間を変換しない（変換すると明るさが少し変わるため）
    private static func grayIfColorless(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard let rgbx = draw(image, width: width, height: height, components: 3),
              let source = rgbx.dataProvider?.data as Data?,
              ColorlessPixels.isNearlyGray(rgbx: source, width: width, height: height, rowBytes: rgbx.bytesPerRow) else {
            return nil
        }
        var gray = Data(count: width * height)
        let rowBytes = rgbx.bytesPerRow
        gray.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
            source.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                for row in 0..<height {
                    for column in 0..<width {
                        let pixel = row * rowBytes + column * 4
                        let sum = Int(input[pixel]) + Int(input[pixel + 1]) + Int(input[pixel + 2])
                        output[row * width + column] = UInt8((sum + 1) / 3)
                    }
                }
            }
        }
        return Self.image(fromPixels: gray, width: width, height: height, components: 1)
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
