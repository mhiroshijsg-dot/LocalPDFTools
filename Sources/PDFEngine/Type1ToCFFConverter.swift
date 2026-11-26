/// Type1 フォント（PDF の /FontFile）を、同じ形の CFF フォント（/FontFile3 /Type1C）に作り直す。
/// 字形の形はそのまま（線と曲線を同じ座標で書き直す）なので、見た目は変わらない。
/// LaTeX の PDF の Type1 フォントは、暗号化されていて圧縮が効かず、使わない下請け（Subrs）もすべて入っているので、
/// CFF にすると数分の 1 になる（iLovePDF も同じことをしている）。
/// 読めない形・知らない命令があれば nil を返す（呼ぶ側はそのフォントを元のまま残す）。
/// MEMO(2026-11-27・by claude): 村田さんの指示（案 B と一緒に「A」）。圧縮のときにいつも行う（見た目は変わらない）。
struct Type1ToCFFConverter {
    func convert(_ data: [UInt8], length1: Int, length2: Int) -> [UInt8]? {
        guard let font = try? Type1FontParser().parse(data, length1: length1, length2: length2) else { return nil }
        let charStrings = Dictionary(font.charStrings.map { ($0.name, $0.data) }, uniquingKeysWith: { first, _ in first })
        let interpreter = Type1CharStringInterpreter(subrs: font.subrs, charStrings: charStrings)

        // 字形の並び: .notdef → 文字の番号を持つ字形（番号の小さい順）→ 番号を持たない字形（フォントの中の順）
        var names = font.charStrings.map(\.name).filter { $0 != ".notdef" }
        if let encoding = font.encoding {
            var firstCode: [String: Int] = [:]
            for (code, name) in encoding where name != ".notdef" {
                firstCode[name] = min(firstCode[name] ?? Int.max, code)
            }
            let encoded = names.filter { firstCode[$0] != nil }.sorted { firstCode[$0]! < firstCode[$1]! }
            // CFF の表は、番号を持つ字形の数も、2 つ目以降の番号（補足）の数も 255 までしか書けない
            let extraCodes = encoding.filter { $0.value != ".notdef" && charStrings[$0.value] != nil }.count - encoded.count
            guard encoded.count <= 255, extraCodes <= 255 else { return nil }
            names = encoded + names.filter { firstCode[$0] == nil }
        }

        var glyphs: [(name: String, charString: [UInt8])] = []
        do {
            let notdef = charStrings[".notdef"] != nil ? try interpreter.outline(of: ".notdef") : GlyphOutline()
            glyphs.append((".notdef", Type2CharStringEncoder.encode(notdef)))
            for name in names {
                glyphs.append((name, Type2CharStringEncoder.encode(try interpreter.outline(of: name))))
            }
        } catch {
            return nil
        }
        guard glyphs.count <= 65535 else { return nil }
        return CFFWriter().write(font: font, glyphs: glyphs)
    }
}
