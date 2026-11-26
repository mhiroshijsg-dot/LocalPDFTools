import Foundation

/// Type1 フォントの中身（PDF の /FontFile のデータ）を読む。
/// 前半（平文）からフォントの名前・行列・枠・文字の割り当てを、後半（eexec で暗号化）から Private 辞書・Subrs・CharStrings を取り出す。
/// 読めない形なら throw する（呼ぶ側はそのフォントを作り直さずに元のまま残す）。
struct Type1FontParser {
    enum ParseError: Error {
        case missingEncryptedPart
        case unexpectedToken(String)
        case unsupported(String)
    }

    /// length1: 平文の長さ（PDF の /Length1）。length2: 暗号化した部分の長さ（/Length2。0 なら最後まで）
    func parse(_ data: [UInt8], length1: Int, length2: Int) throws -> Type1Font {
        guard length1 > 0, length1 < data.count else { throw ParseError.missingEncryptedPart }
        let clear = String(decoding: data[0..<length1], as: Unicode.ASCII.self)
        var font = Type1Font()
        try readClearText(clear, into: &font)

        let end = length2 > 0 ? min(data.count, length1 + length2) : data.count
        var encrypted = Array(data[length1..<end])
        if Self.isHex(encrypted.prefix(4)) { encrypted = Self.hexDecode(encrypted) }
        let decrypted = Self.decrypt(encrypted, key: 55665, skip: 4)
        try readPrivate(decrypted, into: &font)
        return font
    }

    // MARK: 平文

    private func readClearText(_ text: String, into font: inout Type1Font) throws {
        let tokens = PostScriptTokens(text)
        if let name = tokens.value(after: "/FontName"), name.hasPrefix("/") { font.fontName = String(name.dropFirst()) }
        if let matrix = tokens.numbers(after: "/FontMatrix"), matrix.count == 6 { font.fontMatrix = matrix }
        if let box = tokens.numbers(after: "/FontBBox"), box.count == 4 { font.fontBBox = box }
        if let paint = tokens.value(after: "/PaintType").flatMap(Double.init) { font.paintType = Int(paint) }
        font.italicAngle = tokens.value(after: "/ItalicAngle").flatMap(Double.init)
        font.underlinePosition = tokens.value(after: "/UnderlinePosition").flatMap(Double.init)
        font.underlineThickness = tokens.value(after: "/UnderlineThickness").flatMap(Double.init)
        font.isFixedPitch = tokens.value(after: "/isFixedPitch") == "true"

        // 文字の割り当て: "StandardEncoding" か、"dup 65 /A put" の並び
        guard let start = tokens.index(of: "/Encoding") else { throw ParseError.unsupported("文字の割り当てが無い") }
        let next = tokens.items[safe: start + 1]
        if next == "StandardEncoding" {
            font.encoding = nil
        } else if next == "ExpertEncoding" {
            throw ParseError.unsupported("ExpertEncoding")
        } else {
            var encoding: [Int: String] = [:]
            var index = start + 1
            while index + 3 < tokens.items.count {
                let token = tokens.items[index]
                if token == "readonly" || token == "def" { break }
                if token == "dup", let code = Int(tokens.items[index + 1]), tokens.items[index + 2].hasPrefix("/"),
                   tokens.items[index + 3] == "put" {
                    encoding[code] = String(tokens.items[index + 2].dropFirst())
                    index += 4
                } else {
                    index += 1
                }
            }
            font.encoding = encoding
        }
    }

    // MARK: 暗号化した部分

    private func readPrivate(_ bytes: [UInt8], into font: inout Type1Font) throws {
        var scanner = Type1BinaryScanner(bytes: bytes)
        let numericKeys: Set<String> = ["/BlueValues", "/OtherBlues", "/FamilyBlues", "/FamilyOtherBlues", "/BlueScale",
                                        "/BlueShift", "/BlueFuzz", "/StdHW", "/StdVW", "/StemSnapH", "/StemSnapV",
                                        "/LanguageGroup", "/ExpansionFactor"]
        while let token = scanner.next() {
            if numericKeys.contains(token) {
                if let values = scanner.numbers() { font.privateValues[token] = values }
            } else if token == "/ForceBold" {
                if scanner.next() == "true" { font.privateValues[token] = [1] }
            } else if token == "/lenIV" {
                if let value = scanner.next().flatMap(Double.init) { font.lenIV = Int(value) }
            } else if token == "/Subrs" {
                guard let count = scanner.next().flatMap(Int.init), scanner.next() == "array" else {
                    throw ParseError.unexpectedToken("/Subrs")
                }
                var subrs = [[UInt8]](repeating: [], count: count)
                while scanner.peek() == "dup" {
                    _ = scanner.next()
                    guard let index = scanner.next().flatMap(Int.init), let length = scanner.next().flatMap(Int.init),
                          let rd = scanner.next(), Self.isReadData(rd), let raw = scanner.binary(length) else {
                        throw ParseError.unexpectedToken("Subrs の中身")
                    }
                    if index >= 0 && index < count { subrs[index] = decryptCharString(raw, lenIV: font.lenIV) }
                    scanner.skipPut()
                }
                font.subrs = subrs
            } else if token == "/CharStrings" {
                // "/CharStrings 130 dict dup begin" の後に "/名前 長さ RD <中身> ND" が並ぶ
                while let word = scanner.next(), word != "begin" { _ = word }
                while let name = scanner.next(), name != "end" {
                    guard name.hasPrefix("/"), let length = scanner.next().flatMap(Int.init),
                          let rd = scanner.next(), Self.isReadData(rd), let raw = scanner.binary(length) else {
                        throw ParseError.unexpectedToken("CharStrings の中身")
                    }
                    font.charStrings.append((String(name.dropFirst()), decryptCharString(raw, lenIV: font.lenIV)))
                    scanner.skipDefine()
                }
                break
            }
        }
        guard !font.charStrings.isEmpty else { throw ParseError.unsupported("字形が無い") }
    }

    private func decryptCharString(_ raw: [UInt8], lenIV: Int) -> [UInt8] {
        lenIV < 0 ? raw : Self.decrypt(raw, key: 4330, skip: lenIV)
    }

    /// "RD" と "-|" は、どちらも「続く長さのバイトをそのまま読む」
    static func isReadData(_ token: String) -> Bool {
        token == "RD" || token == "-|"
    }

    /// Type1 の暗号を解く（eexec は key 55665、字形の描き方は key 4330）。先頭の skip バイトは捨てる
    static func decrypt(_ bytes: [UInt8], key: UInt16, skip: Int) -> [UInt8] {
        var r = key
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        for byte in bytes {
            output.append(byte ^ UInt8(r >> 8))
            r = (UInt16(byte) &+ r) &* 52845 &+ 22719
        }
        return skip <= output.count ? Array(output.dropFirst(skip)) : []
    }

    private static func isHex<S: Sequence>(_ bytes: S) -> Bool where S.Element == UInt8 {
        bytes.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
    }

    private static func hexDecode(_ bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        var high: UInt8?
        for byte in bytes {
            let value: UInt8
            switch byte {
            case 48...57: value = byte - 48
            case 65...70: value = byte - 55
            case 97...102: value = byte - 87
            default: continue
            }
            if let h = high { output.append(h << 4 | value); high = nil } else { high = value }
        }
        return output
    }
}
