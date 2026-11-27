import CoreGraphics
import Foundation

/// PDF の中身を読んで、大きさの内訳と画像の一覧（ページ上の解像度つき）を作る。中身は変えない。
/// 部品の一覧を読むだけなので速い（画像のデータそのものは読まない）。
public struct PDFContentAnalyzer {
    let runner: QPDFRunner

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    public func analyze(_ url: URL) async throws -> PDFContentReport {
        try analyze(url, table: try await QPDFObjectTable.load(url, runner: runner))
    }

    /// 部品の一覧をすでに読んであるとき
    func analyze(_ url: URL, table: QPDFObjectTable) throws -> PDFContentReport {
        guard let document = CGPDFDocument(url as CFURL), document.isUnlocked else {
            throw EngineError.passwordRequired(path: url.path)
        }
        let scanner = ImagePlacementScanner(table: table)
        scanner.scan(document)
        return report(table, placements: scanner.largestPlacement, totalBytes: FileSize.of(url) ?? 0)
    }

    func report(_ table: QPDFObjectTable, placements: [String: CGSize], totalBytes: Int64) -> PDFContentReport {
        var images: [PDFImageInfo] = []
        var fontFileRefs = Set<String>()
        // 透明度（/SMask）や形の抜き（/Mask）として使われている画像。単独では描かれないので触らない
        var maskRefs = Set<String>()
        for (_, object) in table.objects {
            let dictionary = (object["stream"] as? [String: Any])?["dict"] as? [String: Any]
                ?? object["value"] as? [String: Any]
            guard let dictionary else { continue }
            for key in ["/SMask", "/Mask"] {
                if let ref = dictionary[key] as? String, QPDFObjectTable.isReference(ref) { maskRefs.insert(ref) }
            }
            if (dictionary["/Type"] as? String) == "/FontDescriptor" {
                for key in ["/FontFile", "/FontFile2", "/FontFile3"] {
                    if let ref = dictionary[key] as? String { fontFileRefs.insert(ref) }
                }
            }
        }

        var fontBytes: Int64 = 0
        for (ref, object) in table.objects {
            guard let dictionary = (object["stream"] as? [String: Any])?["dict"] as? [String: Any] else { continue }
            let length = Int64(table.number(dictionary["/Length"]) ?? 0)
            if fontFileRefs.contains(ref) { fontBytes += length }
            guard (dictionary["/Subtype"] as? String) == "/Image" else { continue }
            images.append(imageInfo(ref: ref, dictionary: dictionary, length: length, table: table,
                                    placedSize: placements[ref], isMask: maskRefs.contains(ref)))
        }
        images.sort { $0.byteCount > $1.byteCount }
        return PDFContentReport(totalBytes: totalBytes, images: images, fontBytes: fontBytes)
    }

    private func imageInfo(ref: String, dictionary: [String: Any], length: Int64, table: QPDFObjectTable,
                           placedSize: CGSize?, isMask: Bool) -> PDFImageInfo {
        let filters = Self.filters(dictionary["/Filter"], table: table)
        let encoding: PDFImageInfo.Encoding
        switch filters {
        case ["/DCTDecode"]: encoding = .jpeg
        case ["/FlateDecode"]: encoding = .flate
        default: encoding = .other(filters.map { String($0.dropFirst()) }.joined(separator: "+"))
        }
        let components = Self.components(of: dictionary["/ColorSpace"], table: table)
        let bits = Int(table.number(dictionary["/BitsPerComponent"]) ?? 0)

        // 形式の理由（ページ上の場所は別に見る）
        let formatReason: String?
        if isMask {
            formatReason = String(localized: "透明度や形の抜きに使う画像", bundle: .engine)
        } else if (dictionary["/ImageMask"] as? Bool) == true {
            formatReason = String(localized: "形だけの画像（ImageMask）", bundle: .engine)
        } else if case .other(let name) = encoding {
            switch name {
            case "CCITTFaxDecode", "JBIG2Decode": formatReason = String(localized: "白黒スキャン（\(name == "JBIG2Decode" ? "JBIG2" : "CCITT")）", bundle: .engine)
            case "JPXDecode": formatReason = "JPEG 2000"
            case "": formatReason = String(localized: "圧縮されていない画像", bundle: .engine)
            default: formatReason = String(localized: "対応していない形式（\(name)）", bundle: .engine)
            }
        } else if components == 4 {
            formatReason = String(localized: "印刷用の色（CMYK）", bundle: .engine)
        } else if components == nil {
            formatReason = String(localized: "対応していない色の形式", bundle: .engine)
        } else if bits != 8 {
            formatReason = String(localized: "1 色 \(bits) ビットの画像", bundle: .engine)
        } else if dictionary["/Decode"] != nil {
            formatReason = String(localized: "色の読み替え（/Decode）付き", bundle: .engine)
        } else {
            formatReason = nil
        }
        let reason = formatReason ?? (placedSize == nil ? String(localized: "ページ上で描かれている場所が分からない画像", bundle: .engine) : nil)

        return PDFImageInfo(ref: ref,
                            pixelWidth: Int(table.number(dictionary["/Width"]) ?? 0),
                            pixelHeight: Int(table.number(dictionary["/Height"]) ?? 0),
                            byteCount: length,
                            encoding: encoding,
                            components: components,
                            placedSize: placedSize,
                            unsupportedReason: reason,
                            isRewritable: formatReason == nil)
    }

    static func filters(_ value: Any?, table: QPDFObjectTable) -> [String] {
        switch table.resolve(value) {
        case let name as String: return [name]
        case let array as [Any]: return array.compactMap { table.resolve($0) as? String }
        default: return []
        }
    }

    /// 色の数。灰色・RGB・CMYK と、その ICC 付き・Cal 付きだけ数える（索引色などは nil）
    static func components(of value: Any?, table: QPDFObjectTable) -> Int? {
        switch table.resolve(value) {
        case let name as String:
            switch name {
            case "/DeviceGray", "/G": return 1
            case "/DeviceRGB", "/RGB": return 3
            case "/DeviceCMYK", "/CMYK": return 4
            default: return nil
            }
        case let array as [Any]:
            guard let family = table.resolve(array.first) as? String else { return nil }
            switch family {
            case "/ICCBased":
                guard array.count > 1, let ref = array[1] as? String,
                      let n = table.number(table.streamDictionary(ref)?["/N"]) else { return nil }
                return Int(n)
            case "/CalGray": return 1
            case "/CalRGB": return 3
            default: return nil
            }
        default:
            return nil
        }
    }
}
