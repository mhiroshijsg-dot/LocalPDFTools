import Foundation

/// 検査用の小さな Type1 フォントと、それを使う PDF を作る（Type1 → CFF の作り直しを確かめるため）。
/// 字形は Type1 の命令をなるべく全部使うように作る:
/// - A: 手がかり（hstem・vstem）・線・closepath
/// - B: 手がかりの入れ替え（othersubr 3）・下請け（callsubr）・割り算（div。端数の座標）
/// - D: flex（othersubr 0・1・2 と setcurrentpoint）
/// - E: hstem3・vstem3・dotsection・hlineto・vlineto・hmoveto・vmoveto
/// - O: rrcurveto・hvcurveto・vhcurveto（外側と内側の 2 つの輪郭）
/// - Aacute: アクセント付きの字（seac。A と acute を重ねる）
/// PDF では、同じフォントを「/Differences で番号を決めたもの」と「フォントに組み込まれた割り当てを使うもの」の 2 つの書体で使う。
struct Type1FontFactory {
    let directory: URL
    let qpdf: URL

    /// broken: B の描き方に知らない命令を入れる（作り直せず、元のまま残ることを確かめる）
    func makePDF(name: String, broken: Bool = false) throws -> URL {
        let font = fontProgram(broken: broken)
        let widths: [String: Int] = [".notdef": 500, "A": 600, "B": 600, "D": 600, "E": 500, "O": 700,
                                     "acute": 300, "Aacute": 600]
        let differences = ["A", "B", "D", "E", "O", "acute", "Aacute"]
        let builtIn: [Int: String] = [65: "A", 66: "B", 68: "D", 69: "E", 79: "O", 194: "acute", 201: "Aacute"]
        let builtInWidths = (65...201).map { widths[builtIn[$0] ?? ""] ?? 0 }.map(String.init).joined(separator: " ")
        let differenceWidths = differences.map { String(widths[$0]!) }.joined(separator: " ")
        let content = """
        BT /F1 60 Tf 30 650 Td <01020304050607> Tj ET
        BT /F2 60 Tf 30 500 Td <414244454FC9C2> Tj ET
        BT /F1 24 Tf 30 400 Td <0705040302> Tj ET

        """
        let descriptor = "<< /Type /FontDescriptor /FontName /TESTAA+LPTTest /Flags 4 /FontBBox [0 -10 760 900] "
            + "/ItalicAngle 0 /Ascent 900 /Descent -10 /CapHeight 700 /StemV 60 /FontFile 7 0 R >>"
        let objects: [(Int, String, Data?)] = [
            (1, "<< /Type /Catalog /Pages 2 0 R >>", nil),
            (2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", nil),
            (3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Contents 4 0 R "
                + "/Resources << /Font << /F1 5 0 R /F2 8 0 R >> >> >>", nil),
            (4, "<<", Data(content.utf8)),
            (5, "<< /Type /Font /Subtype /Type1 /BaseFont /TESTAA+LPTTest /FirstChar 1 /LastChar 7 "
                + "/Widths [\(differenceWidths)] /FontDescriptor 6 0 R "
                + "/Encoding << /Type /Encoding /Differences [1 \(differences.map { "/" + $0 }.joined(separator: " "))] >> >>", nil),
            (6, descriptor, nil),
            (7, "<< /Length1 \(font.length1) /Length2 \(font.length2) /Length3 \(font.length3)", font.data),
            (8, "<< /Type /Font /Subtype /Type1 /BaseFont /TESTAA+LPTTest /FirstChar 65 /LastChar 201 "
                + "/Widths [\(builtInWidths)] /FontDescriptor 6 0 R >>", nil),
        ]
        var pdf = Data("%PDF-1.4\n".utf8)
        for (number, dictionary, stream) in objects {
            pdf += Data("\(number) 0 obj\n".utf8)
            if let stream {
                pdf += Data("\(dictionary) /Length \(stream.count) >>\nstream\n".utf8) + stream + Data("\nendstream\n".utf8)
            } else {
                pdf += Data("\(dictionary)\n".utf8)
            }
            pdf += Data("endobj\n".utf8)
        }
        pdf += Data("trailer << /Root 1 0 R /Size 9 >>\n%%EOF\n".utf8)
        let raw = directory.appendingPathComponent("raw-" + name)
        try pdf.write(to: raw)
        let url = directory.appendingPathComponent(name)
        let process = Process()
        process.executableURL = qpdf
        process.arguments = [raw.path, url.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard [0, 3].contains(process.terminationStatus) else { throw SampleError("Type1 の PDF を作れません") }
        return url
    }

    // MARK: フォントの中身

    private func fontProgram(broken: Bool) -> (data: Data, length1: Int, length2: Int, length3: Int) {
        let clear = """
        %!PS-AdobeFont-1.0: LPTTest 001.000
        12 dict begin
        /FontInfo 4 dict dup begin
        /Notice (Test font for LocalPDFTools \\(not for use\\)) readonly def
        /ItalicAngle 0 def
        /UnderlinePosition -100 def
        /UnderlineThickness 50 def
        end readonly def
        /FontName /TESTAA+LPTTest def
        /PaintType 0 def
        /FontType 1 def
        /FontMatrix [0.001 0 0 0.001 0 0] readonly def
        /FontBBox {0 -10 760 900} readonly def
        /Encoding 256 array
        0 1 255 {1 index exch /.notdef put} for
        dup 65 /A put
        dup 66 /B put
        dup 68 /D put
        dup 69 /E put
        dup 79 /O put
        dup 194 /acute put
        dup 201 /Aacute put
        readonly def
        currentdict end
        currentfile eexec

        """
        let subrs: [[Op]] = [
            [3, 0, .callothersubr, .pop, .pop, .setcurrentpoint, .return],
            [0, 1, .callothersubr, .return],
            [0, 2, .callothersubr, .return],
            [.return],
            [.return],
            [400, 0, .rlineto, 0, 600, .rlineto, -800, 2, .div, 0, .rlineto, .closepath, .return],
            [0, 40, .hstem, 560, 40, .hstem, .return],
        ]
        var glyphB: [Op] = [50, 600, .hsbw, 6, 1, 3, .callothersubr, .pop, .callsubr,
                            0, 0, .rmoveto, 5, .callsubr,
                            100, 100, .rmoveto, 301, 2, .div, 0, .rlineto, 0, 200, .rlineto, -301, 2, .div, 0, .rlineto,
                            .closepath, .endchar]
        if broken { glyphB.insert(.unknown, at: 3) }
        let glyphs: [(String, [Op])] = [
            (".notdef", [0, 500, .hsbw, .endchar]),
            ("A", [50, 600, .hsbw, 0, 50, .hstem, 50, 60, .vstem,
                   0, 0, .rmoveto, 500, 0, .rlineto, -250, 700, .rlineto, .closepath, .endchar]),
            ("B", glyphB),
            ("D", [50, 600, .hsbw, 0, 0, .rmoveto, 0, 600, .rlineto, 200, 0, .rlineto,
                   1, .callsubr,
                   200, -300, .rmoveto, 2, .callsubr, -100, 300, .rmoveto, 2, .callsubr,
                   100, -100, .rmoveto, 2, .callsubr, 0, -200, .rmoveto, 2, .callsubr,
                   0, -200, .rmoveto, 2, .callsubr, -100, -100, .rmoveto, 2, .callsubr,
                   -100, 0, .rmoveto, 2, .callsubr,
                   50, 250, 0, 0, .callsubr, .closepath, .endchar]),
            ("E", [50, 500, .hsbw, 0, 40, 330, 40, 660, 40, .hstem3, 0, 60, 150, 60, 300, 60, .vstem3, .dotsection,
                   0, 0, .rmoveto, 400, .hlineto, 40, .vlineto, -340, .hlineto, 290, .vlineto, 300, .hlineto,
                   40, .vlineto, -360, .hlineto, .closepath,
                   380, .hmoveto, 50, .hlineto, 50, .vlineto, -50, .hlineto, .closepath,
                   200, .vmoveto, 50, .hlineto, 50, .vlineto, -50, .hlineto, .closepath, .endchar]),
            ("O", [40, 700, .hsbw, 310, 0, .rmoveto,
                   170, 0, 140, 170, 0, 180, .rrcurveto, 0, 180, -140, 170, -170, 0, .rrcurveto,
                   -170, 0, -140, -170, 0, -180, .rrcurveto, 0, -180, 140, -170, 170, 0, .rrcurveto, .closepath,
                   0, 100, .rmoveto, -100, -90, 120, 130, .hvcurveto, 130, 90, 120, 100, .vhcurveto,
                   100, 90, -120, -130, .hvcurveto, -130, -90, -120, -100, .vhcurveto, .closepath, .endchar]),
            ("acute", [0, 300, .hsbw, 100, 750, .rmoveto, 100, 0, .rlineto, 100, 150, .rlineto, -60, 0, .rlineto,
                       .closepath, .endchar]),
            ("Aacute", [50, 600, .hsbw, 0, 150, 20, 65, 194, .seac]),
        ]

        var privatePart = "dup /Private 10 dict dup begin\n/RD{string currentfile exch readstring pop}executeonly def\n"
            + "/ND{noaccess def}executeonly def\n/NP{noaccess put}executeonly def\n/MinFeature{16 16} ND\n"
            + "/password 5839 def\n/BlueValues [-10 0 700 710] ND\n/BlueScale 0.039625 def\n/StdHW [40] ND\n"
            + "/StdVW [60] ND\n/StemSnapH [40 50] ND\n/lenIV 4 def\n"
        var body = Data(privatePart.utf8)
        privatePart = ""
        body += Data("/Subrs \(subrs.count) array\n".utf8)
        for (index, subr) in subrs.enumerated() {
            let encrypted = Self.encrypt(Self.encode(subr), key: 4330)
            body += Data("dup \(index) \(encrypted.count) RD ".utf8) + encrypted + Data(" NP\n".utf8)
        }
        body += Data("ND\n2 index /CharStrings \(glyphs.count) dict dup begin\n".utf8)
        for (name, ops) in glyphs {
            let encrypted = Self.encrypt(Self.encode(ops), key: 4330)
            body += Data("/\(name) \(encrypted.count) RD ".utf8) + encrypted + Data(" ND\n".utf8)
        }
        body += Data("end\nend\nreadonly put\nnoaccess put\ndup/FontName get exch definefont pop\nmark currentfile closefile\n".utf8)
        let encryptedBody = Self.encrypt(body, key: 55665)
        let trailer = Data((String(repeating: String(repeating: "0", count: 64) + "\n", count: 8) + "cleartomark\n").utf8)
        let clearData = Data(clear.utf8)
        return (clearData + encryptedBody + trailer, clearData.count, encryptedBody.count, trailer.count)
    }

    /// Type1 の命令と数
    enum Op: ExpressibleByIntegerLiteral {
        case number(Int)
        case hstem, vstem, vmoveto, rlineto, hlineto, vlineto, rrcurveto, closepath, callsubr, `return`, hsbw, endchar
        case rmoveto, hmoveto, vhcurveto, hvcurveto
        case dotsection, vstem3, hstem3, seac, div, callothersubr, pop, setcurrentpoint, unknown

        init(integerLiteral value: Int) { self = .number(value) }

        var bytes: [UInt8] {
            switch self {
            case .number(let v):
                switch v {
                case -107...107: return [UInt8(v + 139)]
                case 108...1131: return [UInt8((v - 108) / 256 + 247), UInt8((v - 108) % 256)]
                case -1131 ... -108: return [UInt8((-v - 108) / 256 + 251), UInt8((-v - 108) % 256)]
                default:
                    let u = UInt32(bitPattern: Int32(v))
                    return [255, UInt8(u >> 24), UInt8((u >> 16) & 0xFF), UInt8((u >> 8) & 0xFF), UInt8(u & 0xFF)]
                }
            case .hstem: return [1]
            case .vstem: return [3]
            case .vmoveto: return [4]
            case .rlineto: return [5]
            case .hlineto: return [6]
            case .vlineto: return [7]
            case .rrcurveto: return [8]
            case .closepath: return [9]
            case .callsubr: return [10]
            case .return: return [11]
            case .hsbw: return [13]
            case .endchar: return [14]
            case .rmoveto: return [21]
            case .hmoveto: return [22]
            case .vhcurveto: return [30]
            case .hvcurveto: return [31]
            case .dotsection: return [12, 0]
            case .vstem3: return [12, 1]
            case .hstem3: return [12, 2]
            case .seac: return [12, 6]
            case .div: return [12, 12]
            case .callothersubr: return [12, 16]
            case .pop: return [12, 17]
            case .setcurrentpoint: return [12, 33]
            case .unknown: return [12, 99]
            }
        }
    }

    static func encode(_ ops: [Op]) -> Data {
        Data([0, 0, 0, 0] + ops.flatMap(\.bytes)) // 先頭の 4 バイトは暗号を解くときに捨てる分（lenIV 4）
    }

    static func encrypt(_ plain: Data, key: UInt16) -> Data {
        var r = key
        var output = Data(capacity: plain.count + 4)
        let source = key == 55665 ? Data([0x12, 0x34, 0x56, 0x78]) + plain : plain
        for byte in source {
            let cipher = byte ^ UInt8(r >> 8)
            output.append(cipher)
            r = (UInt16(cipher) &+ r) &* 52845 &+ 22719
        }
        return output
    }
}
