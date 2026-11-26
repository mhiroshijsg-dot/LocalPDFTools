/// Adobe の StandardEncoding（文字の番号 → 字形の名前）。
/// Type1 のアクセント付きの字（seac）は、元の字とアクセントをこの番号で指すので、名前に直すのに使う
enum StandardEncodingNames {
    static func name(of code: Int) -> String? {
        table[code]
    }

    private static let table: [Int: String] = {
        var table: [Int: String] = [:]
        let ascii = ["space", "exclam", "quotedbl", "numbersign", "dollar", "percent", "ampersand", "quoteright",
                     "parenleft", "parenright", "asterisk", "plus", "comma", "hyphen", "period", "slash",
                     "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                     "colon", "semicolon", "less", "equal", "greater", "question", "at"]
        for (offset, name) in ascii.enumerated() { table[32 + offset] = name }
        for (offset, letter) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { table[65 + offset] = String(letter) }
        for (code, name) in [91: "bracketleft", 92: "backslash", 93: "bracketright", 94: "asciicircum",
                             95: "underscore", 96: "quoteleft"] { table[code] = name }
        for (offset, letter) in "abcdefghijklmnopqrstuvwxyz".enumerated() { table[97 + offset] = String(letter) }
        for (code, name) in [123: "braceleft", 124: "bar", 125: "braceright", 126: "asciitilde",
                             161: "exclamdown", 162: "cent", 163: "sterling", 164: "fraction", 165: "yen",
                             166: "florin", 167: "section", 168: "currency", 169: "quotesingle", 170: "quotedblleft",
                             171: "guillemotleft", 172: "guilsinglleft", 173: "guilsinglright", 174: "fi", 175: "fl",
                             177: "endash", 178: "dagger", 179: "daggerdbl", 180: "periodcentered", 182: "paragraph",
                             183: "bullet", 184: "quotesinglbase", 185: "quotedblbase", 186: "quotedblright",
                             187: "guillemotright", 188: "ellipsis", 189: "perthousand", 191: "questiondown",
                             193: "grave", 194: "acute", 195: "circumflex", 196: "tilde", 197: "macron", 198: "breve",
                             199: "dotaccent", 200: "dieresis", 202: "ring", 203: "cedilla", 205: "hungarumlaut",
                             206: "ogonek", 207: "caron", 208: "emdash", 225: "AE", 227: "ordfeminine",
                             232: "Lslash", 233: "Oslash", 234: "OE", 235: "ordmasculine", 241: "ae",
                             245: "dotlessi", 248: "lslash", 249: "oslash", 250: "oe", 251: "germandbls"] {
            table[code] = name
        }
        return table
    }()
}
