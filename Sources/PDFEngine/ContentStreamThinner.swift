import Foundation

/// ページの描画の命令（content stream）を直接書き換えて、図の繰り返しの線を消し、曲線の点を間引く。
/// MEMO(2026-11-26・by claude): 村田さんの `make_compact_pdf.py`（pypdf 版）の判定をそのまま移した。
/// matplotlib の図は、対数軸の補助グリッド線と補助目盛が 1 本ずつ独立した `q … Q` の塊になり、
/// 1 本 200 バイト近くかかる。20〜30 桁の対数軸だと 1 枚で数千本になり、容量の 8 割前後を占めることがある。
/// 命令は文字として扱う（ISO Latin-1 で 1 バイト = 1 文字に読み、書き戻す。バイト列はそのまま保たれる）。
struct ContentStreamThinner {
    /// 同じ見た目の塊が何本以上あれば「グリッド線・目盛の繰り返し」とみなすか（手描きの参照線を消さないための下限）
    static let minimumRepeat = 20

    /// 塊の「見た目」: 塗り方・線の太さ・破線か・線分の長さ
    struct Signature: Hashable {
        let paint: String
        let width: String
        let dashed: Bool
        let length: Double?

        var isGrid: Bool { (paint == "S" || paint == "s") && dashed }
        var isTick: Bool { paint == "B" || paint == "b" }
    }

    /// 最も外側の `q … Q` の塊 1 つ（範囲は NSString の位置）と、その見た目
    struct Group {
        let range: NSRange
        let signature: Signature?
    }

    /// 1 つの流れを読んだ結果
    struct Classified {
        let text: NSString
        let groups: [Group]
        /// 見た目 → (本数, 文字数)
        let stats: [Signature: (count: Int, bytes: Int)]
    }

    // MEMO(2026-11-26・by claude): Python の bytes の正規表現の \s と ^ $ に合わせ、空白は 6 文字だけ・行の区切りは \n だけにする。
    private static let space = "[ \\t\\n\\r\\f\\x0B]"
    private static func regex(_ pattern: String) -> NSRegularExpression {
        // パターンは固定の文字列なので、作れないのはプログラムの誤り
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .useUnixLineSeparators])
    }
    private static let qq = regex("(?:^|\(space))(q|Q)(?=\(space)|$)")
    private static let segment = regex("(?:^|\(space))([lc])(?=\(space)|$)")
    private static let paint = regex("(?:^|\(space))(S|s|B|b|B\\*|b\\*|f|f\\*|F|n)(?=\(space)|$)")
    private static let width = regex("([0-9.]+)\(space)+w(?=\(space)|$)")
    private static let dash = regex("\\[([^\\]]*)\\]\(space)+[0-9.]+\(space)+d(?=\(space)|$)")
    private static let moveTo = regex("(-?[0-9.]+)\(space)+(-?[0-9.]+)\(space)+m(?=\(space)|$)")
    private static let lineTo = regex("(-?[0-9.]+)\(space)+(-?[0-9.]+)\(space)+l(?=\(space)|$)")
    private static let textBegin = regex("BT")
    /// 折れ線: m の後に l が 8 個以上続くもの（matplotlib はデータの点をそのまま l で並べる）
    private static let polyline = regex("(-?[0-9.]+)\(space)+(-?[0-9.]+)\(space)+m\(space)+((?:-?[0-9.]+\(space)+-?[0-9.]+\(space)+l\(space)+){8,})")
    private static let point = regex("(-?[0-9.]+)\(space)+(-?[0-9.]+)\(space)+l")

    // MARK: 読む

    static func classify(_ data: Data) -> Classified {
        let text = NSString(data: data, encoding: String.Encoding.isoLatin1.rawValue) ?? ""
        var groups: [Group] = []
        var stats: [Signature: (count: Int, bytes: Int)] = [:]
        for range in topLevelGroups(text) {
            let signature = signature(text.substring(with: range) as NSString)
            groups.append(Group(range: range, signature: signature))
            if let signature {
                let previous = stats[signature] ?? (0, 0)
                stats[signature] = (previous.count + 1, previous.bytes + range.length)
            }
        }
        return Classified(text: text, groups: groups, stats: stats)
    }

    /// 最も外側の `q … Q` の塊の範囲（対応しない Q は無視）
    private static func topLevelGroups(_ text: NSString) -> [NSRange] {
        var groups: [NSRange] = []
        var depth = 0
        var start: Int?
        for match in qq.matches(in: text as String, range: NSRange(location: 0, length: text.length)) {
            if text.substring(with: match.range(at: 1)) == "q" {
                if depth == 0 { start = match.range.location }
                depth += 1
            } else {
                guard depth > 0 else { continue }
                depth -= 1
                if depth == 0, let begin = start {
                    groups.append(NSRange(location: begin, length: NSMaxRange(match.range) - begin))
                    start = nil
                }
            }
        }
        return groups
    }

    /// 線分 1 本だけを引く塊なら、その見た目。グリッド線・目盛でなければ nil
    private static func signature(_ group: NSString) -> Signature? {
        let string = group as String
        let whole = NSRange(location: 0, length: group.length)
        guard segment.numberOfMatches(in: string, range: whole) == 1,
              textBegin.firstMatch(in: string, range: whole) == nil else { return nil }
        // 塗り（f）を伴うものは除く。線だけ引く塊が対象
        let paints = paint.matches(in: string, range: whole).map { group.substring(with: $0.range(at: 1)) }
        guard let last = paints.filter({ $0 != "n" }).last, ["S", "s", "B", "b"].contains(last) else { return nil }

        let lineWidth = width.firstMatch(in: string, range: whole).map { group.substring(with: $0.range(at: 1)) } ?? "-"
        let dashed = dash.firstMatch(in: string, range: whole).map {
            !group.substring(with: $0.range(at: 1)).split(whereSeparator: { " \t\n\r\u{0C}\u{0B}".contains($0) }).isEmpty
        } ?? false

        var length: Double?
        if let start = moveTo.firstMatch(in: string, range: whole), let end = lineTo.firstMatch(in: string, range: whole),
           let x0 = Double(group.substring(with: start.range(at: 1))), let y0 = Double(group.substring(with: start.range(at: 2))),
           let x1 = Double(group.substring(with: end.range(at: 1))), let y1 = Double(group.substring(with: end.range(at: 2))) {
            length = (hypot(x1 - x0, y1 - y0) * 100).rounded() / 100
        }
        return Signature(paint: last, width: lineWidth, dashed: dashed, length: length)
    }

    /// その流れに現れる目盛（塗り＋線の線分 1 本）の長さ
    static func tickLengths(_ stats: [Signature: (count: Int, bytes: Int)]) -> Set<Double> {
        Set(stats.keys.filter(\.isTick).compactMap(\.length))
    }

    // MARK: 消すものを決める

    /// 消してよい見た目。
    /// - 補助グリッド線: 破線で線を引くだけのもの・繰り返し多数
    /// - 補助目盛: 塗り＋線のうち、文書全体で一番短いもの・繰り返し多数
    /// 目盛の長短は文書全体で見る（主目盛は 1 軸に十数本しか無く、図によっては塗り無しで描くので、
    /// 1 つの流れだけを見ると「長さが 1 種類しかない」と誤って補助目盛を消し損ねる）
    static func removable(_ stats: [Signature: (count: Int, bytes: Int)], grid: Bool, ticks: Bool,
                          documentTickLengths: Set<Double>) -> Set<Signature> {
        var result = Set<Signature>()
        if grid {
            for (signature, stat) in stats where signature.isGrid && stat.count >= minimumRepeat {
                result.insert(signature)
            }
        }
        if ticks {
            let lengths = (documentTickLengths.isEmpty ? tickLengths(stats) : documentTickLengths).sorted()
            if lengths.count >= 2 {
                for (signature, stat) in stats
                where signature.isTick && signature.length == lengths[0] && stat.count >= minimumRepeat {
                    result.insert(signature)
                }
            }
        }
        return result
    }

    // MARK: 書き換える

    /// 消す見た目の塊を取り除く。戻り値: 新しい文・消した本数（グリッド線・目盛）
    static func strip(_ classified: Classified, removing: Set<Signature>) -> (text: String, grid: Int, ticks: Int) {
        guard !removing.isEmpty else { return (classified.text as String, 0, 0) }
        var output = ""
        var position = 0
        var grid = 0
        var ticks = 0
        for group in classified.groups {
            guard let signature = group.signature, removing.contains(signature) else { continue }
            output += classified.text.substring(with: NSRange(location: position, length: group.range.location - position))
            position = NSMaxRange(group.range)
            if signature.isGrid { grid += 1 } else { ticks += 1 }
        }
        output += classified.text.substring(from: position)
        return (output, grid, ticks)
    }

    /// 折れ線の点を、元の線からのずれが tolerance 以内に収まるように間引く。
    /// 戻り値: 新しい文・元の点の数・残した点の数。数として読めないものが混じったら、その流れには触らない
    static func simplifyCurves(_ text: String, tolerance: Double) -> (text: String, before: Int, after: Int) {
        let source = text as NSString
        var output = ""
        var position = 0
        var before = 0
        var after = 0
        for match in polyline.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            guard let x = Double(source.substring(with: match.range(at: 1))),
                  let y = Double(source.substring(with: match.range(at: 2))) else { return (text, 0, 0) }
            var points = [(x, y)]
            let tail = source.substring(with: match.range(at: 3))
            for pointMatch in point.matches(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) {
                guard let px = Double((tail as NSString).substring(with: pointMatch.range(at: 1))),
                      let py = Double((tail as NSString).substring(with: pointMatch.range(at: 2))) else { return (text, 0, 0) }
                points.append((px, py))
            }
            let kept = douglasPeucker(points, tolerance: tolerance)
            before += points.count
            after += kept.count
            var lines = [format(points[0].0) + " " + format(points[0].1) + " m"]
            lines += kept.dropFirst().map { format(points[$0].0) + " " + format(points[$0].1) + " l" }
            output += source.substring(with: NSRange(location: position, length: match.range.location - position))
            output += lines.joined(separator: "\n") + "\n"
            position = NSMaxRange(match.range)
        }
        output += source.substring(from: position)
        return (output, before, after)
    }

    /// Ramer–Douglas–Peucker。残す点の番号を返す（両端は必ず残す）
    static func douglasPeucker(_ points: [(Double, Double)], tolerance: Double) -> [Int] {
        var keep: Set<Int> = [0, points.count - 1]
        var stack = [(0, points.count - 1)]
        while let (i, j) = stack.popLast() {
            guard j > i + 1 else { continue }
            let (x0, y0) = points[i]
            let (x1, y1) = points[j]
            let dx = x1 - x0
            let dy = y1 - y0
            let norm = hypot(dx, dy)
            var farthest = -1.0
            var index = -1
            for k in (i + 1)..<j {
                let (x, y) = points[k]
                let distance = norm > 0 ? abs(dy * (x - x0) - dx * (y - y0)) / norm : hypot(x - x0, y - y0)
                if distance > farthest {
                    farthest = distance
                    index = k
                }
            }
            if farthest > tolerance {
                keep.insert(index)
                stack.append((i, index))
                stack.append((index, j))
            }
        }
        return keep.sorted()
    }

    /// 小数 2 桁で書き、末尾の 0 と小数点を落とす（Python 版の _fmt と同じ）
    private static func format(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.isEmpty ? "0" : text
    }

    static func data(_ text: String) -> Data {
        text.data(using: .isoLatin1) ?? Data(text.utf8)
    }
}
