/// 字形の形（GlyphOutline）を、CFF の字形の描き方（Type2 CharString）にする。
/// 下請けは使わず、線・曲線をそのまま並べる（Type1 の下請けは、使う字形の分だけ展開されるので、使わない分は無くなる）。
/// 送り幅は Private の nominalWidthX = 0・defaultWidthX = 0 を前提に、0 でなければ最初に書く。
/// 手がかり（ステム）は、並べて重ならないものだけを残す（CFF では重なる手がかりを書けないため。形には関わらない）。
enum Type2CharStringEncoder {
    /// Type2 の数の積み上げの上限（48）を超えないように、線・曲線はまとめて書く数を抑える
    private static let maxArguments = 48

    static func encode(_ outline: GlyphOutline) -> [UInt8] {
        var bytes: [UInt8] = []
        var pendingWidth: Double? = outline.width != 0 ? outline.width : nil

        func number(_ value: Double) -> Double {
            let encoded = CFFPrimitives.charStringNumber(value)
            bytes += encoded.bytes
            return encoded.value
        }
        func flushWidth() {
            if let width = pendingWidth {
                _ = number(width)
                pendingWidth = nil
            }
        }

        let horizontal = nonOverlapping(outline.horizontalStems)
        let vertical = nonOverlapping(outline.verticalStems)
        if !horizontal.isEmpty {
            flushWidth()
            writeStems(horizontal, op: 1, number: number, append: { bytes += $0 })
        }
        if !vertical.isEmpty {
            flushWidth()
            writeStems(vertical, op: 3, number: number, append: { bytes += $0 })
        }

        // 読む側が受け取る値（丸めた後）で、今の位置を追う
        var x = 0.0
        var y = 0.0
        var lineArguments = 0
        var curveArguments = 0
        func endRuns() {
            if lineArguments > 0 { bytes.append(5); lineArguments = 0 }
            if curveArguments > 0 { bytes.append(8); curveArguments = 0 }
        }
        func delta(to point: GlyphOutline.Point) {
            x += number(point.x - x)
            y += number(point.y - y)
        }

        for segment in outline.segments {
            switch segment {
            case .move(let point):
                endRuns()
                flushWidth()
                delta(to: point)
                bytes.append(21) // rmoveto
            case .line(let point):
                if curveArguments > 0 || lineArguments + 2 > maxArguments { endRuns() }
                delta(to: point)
                lineArguments += 2
            case .curve(let a, let b, let c):
                if lineArguments > 0 || curveArguments + 6 > maxArguments { endRuns() }
                delta(to: a)
                delta(to: b)
                delta(to: c)
                curveArguments += 6
            }
        }
        endRuns()
        flushWidth()
        bytes.append(14) // endchar
        return bytes
    }

    /// 位置の順に並べ、前のものと重なるものを除く
    static func nonOverlapping(_ stems: [GlyphOutline.Stem]) -> [GlyphOutline.Stem] {
        var result: [GlyphOutline.Stem] = []
        var lastEnd = -Double.infinity
        let sorted = stems.sorted { min($0.position, $0.position + $0.width) < min($1.position, $1.position + $1.width) }
        for stem in sorted {
            let low = min(stem.position, stem.position + stem.width)
            let high = max(stem.position, stem.position + stem.width)
            guard low >= lastEnd, !result.contains(stem) else { continue }
            result.append(stem)
            lastEnd = high
        }
        return result
    }

    /// hstem / vstem: 1 つ目は位置、2 つ目からは前の端からの差。
    /// 命令を分けると位置の数え方が 0 からやり直しになるので、1 つの命令に収まる数（送り幅と合わせて 48 以内＝23 本）までにする
    private static func writeStems(_ stems: [GlyphOutline.Stem], op: UInt8,
                                   number: (Double) -> Double, append: ([UInt8]) -> Void) {
        var edge = 0.0
        for stem in stems.prefix(23) {
            let start = number(stem.position - edge)
            let width = number(stem.width)
            edge += start + width
        }
        append([op])
    }
}
