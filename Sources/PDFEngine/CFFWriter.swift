/// 読み取った Type1 フォントと、CFF の形にした字形から、CFF のフォント（PDF の /FontFile3 /Type1C）を組み立てる。
/// 並び: ヘッダー・名前の INDEX・Top DICT の INDEX・文字列の INDEX・共通の下請けの INDEX（空）・
/// 字形の名前の表（charset）・文字の割り当て（encoding。標準なら無し）・字形の INDEX・Private DICT。
/// MEMO(2026-11-27・by claude): 字形の名前は、CFF の決まった名前の表（SID 0〜390）を使わず、すべて文字列の INDEX に入れる
/// （決まった表を写し間違える危険を避けるため。読む側は番号から名前を引くだけなので、どちらでも同じに読める）。
struct CFFWriter {
    /// glyphs: 字形の名前と CFF の描き方。先頭は .notdef
    func write(font: Type1Font, glyphs: [(name: String, charString: [UInt8])]) -> [UInt8] {
        // 文字列: 字形の名前（.notdef を除く）。番号は 391 から
        var strings: [[UInt8]] = []
        var sid: [String: Int] = [:]
        func stringID(_ text: String) -> Int {
            if let id = sid[text] { return id }
            let id = 391 + strings.count
            strings.append(Array(text.utf8))
            sid[text] = id
            return id
        }
        let glyphSIDs = glyphs.dropFirst().map { stringID($0.name) }

        // 字形の名前の表（形式 0）
        var charset: [UInt8] = [0]
        for id in glyphSIDs { charset += [UInt8(id >> 8), UInt8(id & 0xFF)] }

        // 文字の割り当て（標準でなければ、形式 0 と、同じ字形に 2 つ目以降の番号を付ける補足）
        let encodingBytes = font.encoding.map { encodingTable($0, glyphs: glyphs.map(\.name), stringID: stringID) }

        let charStrings = CFFPrimitives.index(glyphs.map(\.charString))
        let privateDict = privateDictionary(font)

        // Top DICT は場所の数をいつも 5 バイトで書くので、場所が決まる前に大きさが分かる
        func topDictionary(charsetOffset: Int, encodingOffset: Int?, charStringsOffset: Int, privateOffset: Int) -> [UInt8] {
            var bytes: [UInt8] = []
            func entry(_ values: [Double], _ op: Int) {
                for value in values { bytes += CFFPrimitives.dictNumber(value) }
                bytes += CFFPrimitives.dictOperator(op)
            }
            if font.isFixedPitch { entry([1], 1201) }
            if let angle = font.italicAngle, angle != 0 { entry([angle], 1202) }
            if let position = font.underlinePosition { entry([position], 1203) }
            if let thickness = font.underlineThickness { entry([thickness], 1204) }
            if font.paintType != 0 { entry([Double(font.paintType)], 1205) }
            if font.fontMatrix != [0.001, 0, 0, 0.001, 0, 0] { entry(font.fontMatrix, 1207) }
            entry(font.fontBBox, 5)
            bytes += CFFPrimitives.fixedDictInteger(charsetOffset) + [15]
            if let encodingOffset { bytes += CFFPrimitives.fixedDictInteger(encodingOffset) + [16] }
            bytes += CFFPrimitives.fixedDictInteger(charStringsOffset) + [17]
            bytes += CFFPrimitives.fixedDictInteger(privateDict.count) + CFFPrimitives.fixedDictInteger(privateOffset) + [18]
            return bytes
        }

        let header: [UInt8] = [1, 0, 4, 4]
        let nameIndex = CFFPrimitives.index([Array(font.fontName.utf8)])
        let stringIndex = CFFPrimitives.index(strings)
        let globalSubrs = CFFPrimitives.index([])
        let placeholder = topDictionary(charsetOffset: 0, encodingOffset: encodingBytes == nil ? nil : 0,
                                        charStringsOffset: 0, privateOffset: 0)
        let topIndexSize = CFFPrimitives.index([placeholder]).count

        let charsetOffset = header.count + nameIndex.count + topIndexSize + stringIndex.count + globalSubrs.count
        let encodingOffset = encodingBytes == nil ? nil : charsetOffset + charset.count
        let charStringsOffset = charsetOffset + charset.count + (encodingBytes?.count ?? 0)
        let privateOffset = charStringsOffset + charStrings.count
        let topIndex = CFFPrimitives.index([topDictionary(charsetOffset: charsetOffset, encodingOffset: encodingOffset,
                                                          charStringsOffset: charStringsOffset, privateOffset: privateOffset)])

        return header + nameIndex + topIndex + stringIndex + globalSubrs + charset + (encodingBytes ?? [])
            + charStrings + privateDict
    }

    /// 文字の割り当ての表。字形の番号の順（1 から）に、その字形の一番小さい文字の番号を並べ、残りの番号は補足に書く。
    /// CFF の形式 0 は「字形 1 から n までの番号」なので、番号を持つ字形を先に並べておく必要がある（呼ぶ側の並べ方を参照）
    private func encodingTable(_ encoding: [Int: String], glyphs: [String], stringID: (String) -> Int) -> [UInt8] {
        var codes: [String: [Int]] = [:]
        for (code, name) in encoding where name != ".notdef" && (0...255).contains(code) {
            codes[name, default: []].append(code)
        }
        var primary: [UInt8] = []
        var supplements: [(code: Int, name: String)] = []
        for name in glyphs.dropFirst() {
            guard let list = codes[name]?.sorted(), let first = list.first else { break }
            primary.append(UInt8(first))
            for extra in list.dropFirst() { supplements.append((extra, name)) }
        }
        var bytes: [UInt8] = [supplements.isEmpty ? 0 : 0x80, UInt8(primary.count)] + primary
        if !supplements.isEmpty {
            bytes.append(UInt8(supplements.count))
            for supplement in supplements {
                let id = stringID(supplement.name)
                bytes += [UInt8(supplement.code), UInt8(id >> 8), UInt8(id & 0xFF)]
            }
        }
        return bytes
    }

    private func privateDictionary(_ font: Type1Font) -> [UInt8] {
        var bytes: [UInt8] = []
        let deltaKeys: [(String, Int)] = [("/BlueValues", 6), ("/OtherBlues", 7), ("/FamilyBlues", 8),
                                          ("/FamilyOtherBlues", 9), ("/StemSnapH", 1212), ("/StemSnapV", 1213)]
        for (key, op) in deltaKeys {
            guard let values = font.privateValues[key], !values.isEmpty else { continue }
            for value in CFFPrimitives.deltaArray(values) { bytes += CFFPrimitives.dictNumber(value) }
            bytes += CFFPrimitives.dictOperator(op)
        }
        let singleKeys: [(String, Int)] = [("/StdHW", 10), ("/StdVW", 11), ("/BlueScale", 1209), ("/BlueShift", 1210),
                                           ("/BlueFuzz", 1211), ("/ForceBold", 1214), ("/LanguageGroup", 1217),
                                           ("/ExpansionFactor", 1218)]
        for (key, op) in singleKeys {
            guard let value = font.privateValues[key]?.first else { continue }
            bytes += CFFPrimitives.dictNumber(value) + CFFPrimitives.dictOperator(op)
        }
        return bytes
    }
}
