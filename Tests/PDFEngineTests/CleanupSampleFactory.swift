import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 圧縮でいつも行う 3 つ（要らないデータ・重複・色の無い画像）を確かめる PDF を作る。
/// 1 ページに次のものを入れる（PDF を文字とバイトで書き、qpdf に目録を作らせ、圧縮していない画像を可逆で圧縮させる）:
/// - カタログとページの /PieceInfo（Illustrator の編集用データに似せた大きなデータ）・ページの /Thumb・
///   カタログの /Metadata（残すもの）・色の画像に付いた /Metadata（外すもの）
/// - /Ga と /Gb: 中身がまったく同じ、R・G・B がぴったり同じ可逆の画像（重複でまとまり、灰色になる）
/// - /Col: 色の付いた可逆の画像（灰色にしない）
/// - /Jg: 灰色の中身を、カラーのスキャンのように少し色のぶれを付けて RGB で保存した JPEG（灰色になる）
/// - /Jc: 灰色の中身に赤い印鑑のような丸がある JPEG（灰色にしない）
struct CleanupSampleFactory {
    let directory: URL
    let qpdf: URL

    /// 各画像をページのどこに置いたか（ポイント。左下が原点）
    static let placements: [String: CGRect] = [
        "Ga": CGRect(x: 20, y: 600, width: 200, height: 100),
        "Gb": CGRect(x: 260, y: 600, width: 200, height: 100),
        "Col": CGRect(x: 20, y: 450, width: 100, height: 100),
        "Jg": CGRect(x: 20, y: 100, width: 240, height: 180),
        "Jc": CGRect(x: 300, y: 100, width: 240, height: 180),
    ]

    func make(name: String) throws -> URL {
        let grayPixels = Self.rgbPixels(width: 200, height: 100) { x, y in
            let v = UInt8((x * 3 + y * 5) % 256)
            return (v, v, v)
        }
        let colorPixels = Self.rgbPixels(width: 100, height: 100) { x, y in
            (UInt8((x * 2) % 256), UInt8((y * 2) % 256), 128)
        }
        let grayJPEG = try Self.jpeg(width: 400, height: 300, stamp: false)
        let stampJPEG = try Self.jpeg(width: 400, height: 300, stamp: true)
        let thumb = Data(repeating: 200, count: 10 * 10)
        // 編集用のデータは、圧縮しても小さくならない中身にする（本物の Illustrator のデータも圧縮済みで小さくならない）
        var seed: UInt32 = 12345
        let privateData = Data((0..<50_000).map { _ -> UInt8 in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return UInt8(truncatingIfNeeded: seed >> 24)
        })
        let xmp = Data("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF/></x:xmpmeta>".utf8)

        var content = ""
        for (name, rect) in Self.placements.sorted(by: { $0.key < $1.key }) {
            content += "q \(Int(rect.width)) 0 0 \(Int(rect.height)) \(Int(rect.minX)) \(Int(rect.minY)) cm /\(name) Do Q\n"
        }

        let rgb8 = "/Type /XObject /Subtype /Image /ColorSpace /DeviceRGB /BitsPerComponent 8"
        let objects: [(Int, String, Data?)] = [
            (1, "<< /Type /Catalog /Pages 2 0 R /Metadata 9 0 R /PieceInfo << /Illustrator << /Private 10 0 R >> >> >>", nil),
            (2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", nil),
            (3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Contents 4 0 R "
                + "/Resources << /XObject << /Ga 5 0 R /Gb 6 0 R /Col 7 0 R /Jg 8 0 R /Jc 11 0 R >> >> "
                + "/PieceInfo << /Illustrator << /Private 12 0 R >> >> /Thumb 13 0 R >>", nil),
            (4, "<<", Data(content.utf8)),
            (5, "<< \(rgb8) /Width 200 /Height 100", grayPixels),
            (6, "<< \(rgb8) /Width 200 /Height 100", grayPixels),
            (7, "<< \(rgb8) /Width 100 /Height 100 /Metadata 14 0 R", colorPixels),
            (8, "<< \(rgb8) /Width 400 /Height 300 /Filter /DCTDecode", grayJPEG),
            (9, "<< /Type /Metadata /Subtype /XML", xmp),
            (10, "<<", privateData),
            (11, "<< \(rgb8) /Width 400 /Height 300 /Filter /DCTDecode", stampJPEG),
            (12, "<<", privateData + Data("second".utf8)),
            (13, "<< /Width 10 /Height 10 /ColorSpace /DeviceGray /BitsPerComponent 8", thumb),
            (14, "<< /Type /Metadata /Subtype /XML", xmp),
        ]
        var pdf = Data("%PDF-1.7\n".utf8)
        for (number, dictionary, stream) in objects {
            pdf += Data("\(number) 0 obj\n".utf8)
            if let stream {
                pdf += Data("\(dictionary) /Length \(stream.count) >>\nstream\n".utf8) + stream + Data("\nendstream\n".utf8)
            } else {
                pdf += Data("\(dictionary)\n".utf8)
            }
            pdf += Data("endobj\n".utf8)
        }
        pdf += Data("trailer << /Root 1 0 R /Size 15 >>\n%%EOF\n".utf8)

        let raw = directory.appendingPathComponent("raw-" + name)
        try pdf.write(to: raw)
        let url = directory.appendingPathComponent(name)
        let process = Process()
        process.executableURL = qpdf
        process.arguments = [raw.path, url.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard [0, 3].contains(process.terminationStatus) else { throw SampleError("掃除の見本の PDF を作れません") }
        return url
    }

    private static func rgbPixels(width: Int, height: Int, color: (Int, Int) -> (UInt8, UInt8, UInt8)) -> Data {
        var data = Data(capacity: width * height * 3)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b) = color(x, y)
                data.append(contentsOf: [r, g, b])
            }
        }
        return data
    }

    /// 灰色の地と文字のような形に、カラーのスキャンのような色のぶれを足して、RGB の JPEG（最高の画質。灰色にすると 1 割以上小さくなり、置き換わる例）にする。stamp なら赤い丸（印鑑）を足す
    private static func jpeg(width: Int, height: Int, stamp: Bool) throws -> Data {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw SampleError("画像を作れません") }
        context.setFillColor(CGColor(gray: 0.97, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        for row in stride(from: 20, to: height - 20, by: 18) {
            for column in stride(from: 20, to: width - 40, by: 9) where (row + column) % 5 != 0 {
                context.fill(CGRect(x: column, y: row, width: 6, height: 9))
            }
        }
        if stamp {
            context.setFillColor(CGColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1))
            context.fillEllipse(in: CGRect(x: width - 90, y: 30, width: 50, height: 50))
        }
        // カラーで読み取ったスキャンのように、画素ごとに R・G・B を少しずつ（±3）ぶらす
        guard let buffer = context.data else { throw SampleError("画像を作れません") }
        let bytes = buffer.assumingMemoryBound(to: UInt8.self)
        var seed: UInt32 = 99
        for index in 0..<(context.bytesPerRow * height) where index % 4 != 3 {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Int(seed >> 29) - 3
            bytes[index] = UInt8(clamping: Int(bytes[index]) + noise)
        }
        guard let image = context.makeImage() else { throw SampleError("画像を作れません") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw SampleError("JPEG を作れません")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw SampleError("JPEG を作れません") }
        return data as Data
    }
}
