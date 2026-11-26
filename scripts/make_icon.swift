// アプリのアイコン（AppIcon）の画像を、図形を描いて作る。
// 出力: Sources/LocalPDFTools/Assets.xcassets/AppIcon.appiconset/ の PNG（毎回作り直す）
// 使い方: swift scripts/make_icon.swift
//
// MEMO(2026-11-26・by claude): 画像ソフトで描いたものではなく、このファイルの数値がアイコンの「元」。
// 色や形を変えたいときはここを直して、もう一度実行する。大きさごとに描き直すので、16px でもにじまない。
// 寸法は 1024×1024 の上で考える。Mac のアイコンの決まり（角の丸い四角が 824×824、周りに 100 の余白）に合わせてある。

import AppKit

/// 1 枚のアイコンを描く係。座標は 1024 四方・左上が原点で考え、描くときに実際の大きさへ縮める。
struct IconPainter {
    // 色
    let backgroundTop = NSColor(srgbRed: 0.27, green: 0.53, blue: 0.98, alpha: 1)
    let backgroundBottom = NSColor(srgbRed: 0.11, green: 0.27, blue: 0.72, alpha: 1)
    let backPage = NSColor(srgbRed: 0.80, green: 0.86, blue: 0.97, alpha: 1)
    let frontPage = NSColor.white
    let fold = NSColor(srgbRed: 0.82, green: 0.86, blue: 0.93, alpha: 1)
    let textLine = NSColor(srgbRed: 0.78, green: 0.82, blue: 0.89, alpha: 1)
    let label = NSColor(srgbRed: 0.90, green: 0.22, blue: 0.23, alpha: 1)

    /// 指定の大きさ（ピクセル）で描いた PNG のデータを返す
    func png(pixels: Int) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext
        // 左上を原点にし、1024 四方の数値で描けるようにする
        let scale = CGFloat(pixels) / 1024
        cg.translateBy(x: 0, y: CGFloat(pixels))
        cg.scaleBy(x: scale, y: -scale)
        draw(in: cg)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    private func draw(in cg: CGContext) {
        drawBackground(cg)
        // 後ろの紙（少し傾ける）＝ 複数の PDF をまとめて扱う感じ
        let pageSize = CGSize(width: 430, height: 550)
        let frontOrigin = CGPoint(x: 336, y: 248)
        cg.saveGState()
        cg.translateBy(x: frontOrigin.x + pageSize.width / 2 - 40, y: frontOrigin.y + pageSize.height / 2 - 10)
        cg.rotate(by: -10 * .pi / 180)
        drawPage(cg, rect: CGRect(x: -pageSize.width / 2, y: -pageSize.height / 2,
                                  width: pageSize.width, height: pageSize.height),
                 color: backPage, details: false)
        cg.restoreGState()
        // 手前の紙
        drawPage(cg, rect: CGRect(origin: frontOrigin, size: pageSize), color: frontPage, details: true)
    }

    /// 角の丸い四角（Mac のアイコンの土台）を青の濃淡で塗る
    private func drawBackground(_ cg: CGContext) {
        let body = CGRect(x: 100, y: 100, width: 824, height: 824)
        let path = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
        // 土台の下の薄い影
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 20,
                     color: NSColor.black.withAlphaComponent(0.30).cgColor)
        cg.addPath(path)
        cg.setFillColor(backgroundBottom.cgColor)
        cg.fillPath()
        cg.restoreGState()

        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [backgroundTop.cgColor, backgroundBottom.cgColor] as CFArray,
                                  locations: [0, 1])!
        cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
        cg.restoreGState()
    }

    /// 右上の角が折れた紙を 1 枚描く。details が true なら、文字の行と赤い「PDF」の札も描く
    private func drawPage(_ cg: CGContext, rect r: CGRect, color: NSColor, details: Bool) {
        let foldSize: CGFloat = 120
        let corner: CGFloat = 28
        let outline = CGMutablePath()
        outline.move(to: CGPoint(x: r.minX + corner, y: r.minY))
        outline.addLine(to: CGPoint(x: r.maxX - foldSize, y: r.minY))
        outline.addLine(to: CGPoint(x: r.maxX, y: r.minY + foldSize))
        outline.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: corner)
        outline.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: corner)
        outline.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: corner)
        outline.closeSubpath()

        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 14), blur: 30,
                     color: NSColor.black.withAlphaComponent(0.28).cgColor)
        cg.addPath(outline)
        cg.setFillColor(color.cgColor)
        cg.fillPath()
        cg.restoreGState()

        // 折れた角
        let foldPath = CGMutablePath()
        foldPath.move(to: CGPoint(x: r.maxX - foldSize, y: r.minY))
        foldPath.addLine(to: CGPoint(x: r.maxX - foldSize, y: r.minY + foldSize - 18))
        foldPath.addQuadCurve(to: CGPoint(x: r.maxX - foldSize + 18, y: r.minY + foldSize),
                              control: CGPoint(x: r.maxX - foldSize, y: r.minY + foldSize))
        foldPath.addLine(to: CGPoint(x: r.maxX, y: r.minY + foldSize))
        foldPath.closeSubpath()
        cg.addPath(foldPath)
        cg.setFillColor((details ? fold : fold.blended(withFraction: 0.4, of: backPage)!).cgColor)
        cg.fillPath()

        guard details else { return }

        // 文字の行（上のほう）
        cg.setFillColor(textLine.cgColor)
        let lines: [CGFloat] = [250, 210, 260]   // 各行の長さ
        for (i, length) in lines.enumerated() {
            let line = CGRect(x: r.minX + 50, y: r.minY + 70 + CGFloat(i) * 56, width: length, height: 26)
            cg.addPath(CGPath(roundedRect: line, cornerWidth: 13, cornerHeight: 13, transform: nil))
        }
        cg.fillPath()

        // 赤い「PDF」の札。紙の左の縁から少しはみ出させる
        let labelRect = CGRect(x: r.minX - 46, y: r.minY + 290, width: 380, height: 170)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 8), blur: 16,
                     color: NSColor.black.withAlphaComponent(0.22).cgColor)
        cg.addPath(CGPath(roundedRect: labelRect, cornerWidth: 30, cornerHeight: 30, transform: nil))
        cg.setFillColor(label.cgColor)
        cg.fillPath()
        cg.restoreGState()
        drawLabelText("PDF", in: labelRect, cg)

        // 下のほうにも文字の行を 1 本
        cg.setFillColor(textLine.cgColor)
        cg.addPath(CGPath(roundedRect: CGRect(x: r.minX + 50, y: r.minY + 490, width: 200, height: 26),
                          cornerWidth: 13, cornerHeight: 13, transform: nil))
        cg.fillPath()
    }

    /// 札の真ん中に白い太字を描く
    private func drawLabelText(_ text: String, in rect: CGRect, _ cg: CGContext) {
        let font = NSFont.systemFont(ofSize: 128, weight: .heavy)
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetImageBounds(line, cg)
        cg.saveGState()
        // 文字は下から上へ描かれるので、ここだけ上下を戻す
        cg.translateBy(x: rect.midX - bounds.midX, y: rect.midY)
        cg.scaleBy(x: 1, y: -1)
        cg.textPosition = CGPoint(x: 0, y: -bounds.midY)
        CTLineDraw(line, cg)
        cg.restoreGState()
    }
}

// Mac のアイコンに要る大きさの一覧（ファイル名, ピクセル, Contents.json に書く大きさ, 倍率）
let entries: [(String, Int, String, String)] = [
    ("icon_16.png", 16, "16x16", "1x"), ("icon_32.png", 32, "16x16", "2x"),
    ("icon_32.png", 32, "32x32", "1x"), ("icon_64.png", 64, "32x32", "2x"),
    ("icon_128.png", 128, "128x128", "1x"), ("icon_256.png", 256, "128x128", "2x"),
    ("icon_256.png", 256, "256x256", "1x"), ("icon_512.png", 512, "256x256", "2x"),
    ("icon_512.png", 512, "512x512", "1x"), ("icon_1024.png", 1024, "512x512", "2x"),
]

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let catalog = root.appendingPathComponent("Sources/LocalPDFTools/Assets.xcassets")
let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

let painter = IconPainter()
var written = Set<String>()
for (name, pixels, _, _) in entries where !written.contains(name) {
    try painter.png(pixels: pixels).write(to: iconSet.appendingPathComponent(name))
    written.insert(name)
}

let images = entries.map { "    { \"filename\" : \"\($0.0)\", \"idiom\" : \"mac\", \"scale\" : \"\($0.3)\", \"size\" : \"\($0.2)\" }" }
let contents = "{\n  \"images\" : [\n" + images.joined(separator: ",\n") + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
try contents.write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    .write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("できました: \(iconSet.path)")
