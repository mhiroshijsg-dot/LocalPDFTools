import Foundation

/// CFF（Compact Font Format・Adobe Technical Note #5176）の部品の書き方: 辞書の数・INDEX・字形の描き方の数
enum CFFPrimitives {
    // MARK: 辞書（Top DICT・Private DICT）の数

    /// 辞書の数（整数は短い形、小数は BCD の形）
    static func dictNumber(_ value: Double) -> [UInt8] {
        if value == value.rounded(), abs(value) < 2_147_483_647 {
            return dictInteger(Int(value))
        }
        return dictReal(value)
    }

    static func dictInteger(_ value: Int) -> [UInt8] {
        switch value {
        case -107...107:
            return [UInt8(value + 139)]
        case 108...1131:
            let v = value - 108
            return [UInt8(v / 256 + 247), UInt8(v % 256)]
        case -1131 ... -108:
            let v = -value - 108
            return [UInt8(v / 256 + 251), UInt8(v % 256)]
        case -32768...32767:
            return [28, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        default:
            return fixedDictInteger(value)
        }
    }

    /// いつも 5 バイトの整数（場所を後から埋めるため、長さが変わらない形）
    static func fixedDictInteger(_ value: Int) -> [UInt8] {
        let v = UInt32(bitPattern: Int32(truncatingIfNeeded: value))
        return [29, UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    /// 小数: 30 の後に 1 文字を 4 ビットで（0〜9・a は小数点・b は E・c は E-・e はマイナス・f は終わり）
    static func dictReal(_ value: Double) -> [UInt8] {
        var text = String(value)
        if text.hasSuffix(".0") { text.removeLast(2) }
        var nibbles: [UInt8] = []
        let characters = Array(text.lowercased())
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case "0"..."9": nibbles.append(UInt8(character.asciiValue! - 48))
            case ".": nibbles.append(0xA)
            case "-": nibbles.append(0xE)
            case "e":
                if index + 1 < characters.count && characters[index + 1] == "-" {
                    nibbles.append(0xC)
                    index += 1
                } else {
                    nibbles.append(0xB)
                    if index + 1 < characters.count && characters[index + 1] == "+" { index += 1 }
                }
            default: break
            }
            index += 1
        }
        nibbles.append(0xF)
        if nibbles.count % 2 == 1 { nibbles.append(0xF) }
        var bytes: [UInt8] = [30]
        for i in stride(from: 0, to: nibbles.count, by: 2) { bytes.append(nibbles[i] << 4 | nibbles[i + 1]) }
        return bytes
    }

    /// 辞書の命令（12 の後に続く 2 バイトの命令は 1200 + 番号で渡す）
    static func dictOperator(_ op: Int) -> [UInt8] {
        op >= 1200 ? [12, UInt8(op - 1200)] : [UInt8(op)]
    }

    /// 差で並べる配列（BlueValues・StemSnapH など）
    static func deltaArray(_ values: [Double]) -> [Double] {
        var previous = 0.0
        return values.map { value in
            defer { previous = value }
            return value - previous
        }
    }

    // MARK: INDEX

    /// INDEX: 数（2 バイト）・場所の大きさ・場所（1 から）・中身
    static func index(_ items: [[UInt8]]) -> [UInt8] {
        guard !items.isEmpty else { return [0, 0] }
        let total = items.reduce(0) { $0 + $1.count } + 1
        let offSize = total <= 0xFF ? 1 : total <= 0xFFFF ? 2 : total <= 0xFF_FFFF ? 3 : 4
        var bytes: [UInt8] = [UInt8(items.count >> 8), UInt8(items.count & 0xFF), UInt8(offSize)]
        var offset = 1
        func appendOffset(_ value: Int) {
            for shift in stride(from: (offSize - 1) * 8, through: 0, by: -8) { bytes.append(UInt8((value >> shift) & 0xFF)) }
        }
        appendOffset(offset)
        for item in items {
            offset += item.count
            appendOffset(offset)
        }
        for item in items { bytes += item }
        return bytes
    }

    // MARK: 字形の描き方（Type2）の数

    /// 字形の描き方の数。整数は短い形、小数は 16.16 の固定小数（255 の後に 4 バイト）。
    /// 返す値は、読む側が受け取る値（小数は丸めた後の値）
    static func charStringNumber(_ value: Double) -> (bytes: [UInt8], value: Double) {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-7, abs(rounded) <= 32767 {
            let v = Int(rounded)
            switch v {
            case -107...107:
                return ([UInt8(v + 139)], rounded)
            case 108...1131:
                let w = v - 108
                return ([UInt8(w / 256 + 247), UInt8(w % 256)], rounded)
            case -1131 ... -108:
                let w = -v - 108
                return ([UInt8(w / 256 + 251), UInt8(w % 256)], rounded)
            default:
                return ([28, UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)], rounded)
            }
        }
        let fixed = Int32((value * 65536).rounded())
        let bits = UInt32(bitPattern: fixed)
        return ([255, UInt8(bits >> 24), UInt8((bits >> 16) & 0xFF), UInt8((bits >> 8) & 0xFF), UInt8(bits & 0xFF)],
                Double(fixed) / 65536)
    }
}
