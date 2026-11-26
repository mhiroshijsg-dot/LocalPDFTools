/// 暗号を解いた後半を語に区切って読む。"RD" の後のバイトの並びは、長さのとおりにそのまま読む
struct Type1BinaryScanner {
    let bytes: [UInt8]
    var position = 0
    private var peeked: (token: String, end: Int)?

    init(bytes: [UInt8]) { self.bytes = bytes }

    private static func isSpace(_ byte: UInt8) -> Bool { byte == 32 || byte == 10 || byte == 13 || byte == 9 || byte == 0 }
    private static func isDelimiter(_ byte: UInt8) -> Bool {
        isSpace(byte) || byte == 91 || byte == 93 || byte == 123 || byte == 125 || byte == 40 || byte == 41
            || byte == 47 || byte == 37 || byte == 60 || byte == 62
    }

    mutating func peek() -> String? {
        if let peeked { return peeked.token }
        let start = position
        let token = next()
        if let token { peeked = (token, position) }
        position = start
        return token
    }

    mutating func next() -> String? {
        if let peeked {
            position = peeked.end
            self.peeked = nil
            return peeked.token
        }
        while position < bytes.count {
            let byte = bytes[position]
            if Self.isSpace(byte) { position += 1; continue }
            if byte == 37 { // % から行末まで
                while position < bytes.count && bytes[position] != 10 && bytes[position] != 13 { position += 1 }
                continue
            }
            if byte == 40 { // ( 文字列 ) は丸ごと読み飛ばす
                var depth = 0
                while position < bytes.count {
                    if bytes[position] == 92 { position += 2; continue }
                    if bytes[position] == 40 { depth += 1 }
                    if bytes[position] == 41 { depth -= 1; if depth == 0 { position += 1; break } }
                    position += 1
                }
                return "(string)"
            }
            if byte == 91 || byte == 93 || byte == 123 || byte == 125 {
                position += 1
                return String(UnicodeScalar(byte))
            }
            if byte == 60 || byte == 62 { // < > は 1 文字ずつ（中身は使わない）
                position += 1
                return String(UnicodeScalar(byte))
            }
            let start = position
            position += 1
            while position < bytes.count && !Self.isDelimiter(bytes[position]) { position += 1 }
            return String(decoding: bytes[start..<position], as: Unicode.ASCII.self)
        }
        return nil
    }

    /// "[1 2]"・"{1 2}"・"1" のどれかの数
    mutating func numbers() -> [Double]? {
        guard let token = next() else { return nil }
        if token == "[" || token == "{" {
            var values: [Double] = []
            while let item = next(), item != "]" && item != "}" {
                guard let value = Double(item) else { return nil }
                values.append(value)
            }
            return values
        }
        return Double(token).map { [$0] }
    }

    /// RD の直後の空白 1 文字を飛ばして、length バイトを読む
    mutating func binary(_ length: Int) -> [UInt8]? {
        peeked = nil
        let start = position + 1
        guard length >= 0, start + length <= bytes.count else { return nil }
        position = start + length
        return Array(bytes[start..<(start + length)])
    }

    /// Subrs の 1 つの後の "NP" / "|" / "noaccess put"
    mutating func skipPut() {
        guard let token = peek() else { return }
        if token == "NP" || token == "|" || token == "put" { _ = next() }
        else if token == "noaccess" { _ = next(); if peek() == "put" { _ = next() } }
    }

    /// CharStrings の 1 つの後の "ND" / "|-" / "noaccess def"
    mutating func skipDefine() {
        guard let token = peek() else { return }
        if token == "ND" || token == "|-" || token == "def" { _ = next() }
        else if token == "noaccess" { _ = next(); if peek() == "def" { _ = next() } }
    }
}
