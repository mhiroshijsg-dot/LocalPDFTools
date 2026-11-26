import CoreGraphics
import Foundation

/// PDF の 1 ページを、白い背景の画像に描く（OCR に渡すため）。
/// ページの向き（/Rotate）に加えて、作業台で指定した回転（90° 単位）も反映する。
/// MEMO(2026-11-26・by claude): Core Graphics の drawPDFPage は /Rotate を反映しないので、向きはここで自分で回す。
/// PDFKit の縮小表示（thumbnail）は画面の倍率でピクセル数が変わるため、解像度を決めて描けるこちらを使う。
public struct PageImageRenderer {
    /// 何 dpi で描くか（Vision の推奨は文字の高さが十分あること。300 dpi なら普通の本文で足りる）
    public let dpi: CGFloat
    /// 長い辺のピクセル数の上限（大きな図面のページでメモリを使いすぎないため）
    public let maxPixels: CGFloat

    public init(dpi: CGFloat = 300, maxPixels: CGFloat = 5000) {
        self.dpi = dpi
        self.maxPixels = maxPixels
    }

    /// extraQuarterTurns は時計回りに足す 90° の回数（作業台の回転の指定）
    public func render(_ page: CGPDFPage, extraQuarterTurns: Int = 0) -> CGImage? {
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let degrees = ((Int(page.rotationAngle) + extraQuarterTurns * 90) % 360 + 360) % 360
        let sideways = degrees == 90 || degrees == 270
        let size = sideways ? CGSize(width: box.height, height: box.width) : box.size
        let scale = min(dpi / 72, maxPixels / max(size.width, size.height))
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        // 時計回りに回す（y は上向き）。w・h は回す前のページの幅と高さ
        let w = box.width, h = box.height
        switch degrees {
        case 90:
            context.translateBy(x: 0, y: w)
            context.rotate(by: -.pi / 2)
        case 180:
            context.translateBy(x: w, y: h)
            context.rotate(by: .pi)
        case 270:
            context.translateBy(x: h, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }
        context.translateBy(x: -box.minX, y: -box.minY)
        context.clip(to: box)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
