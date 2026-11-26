import CoreGraphics

/// Vision が返した文字の塊を、ページ上の並びどおりの行に組み立てる。
/// MEMO(2026-11-24・by claude): Vision は塊ごとに位置を返すが、返す順番は行の順とは限らない。
/// 表では列の順番がばらばらになった（計画 §8 の V2）。そこで同じ高さの塊を 1 行にまとめ、左から並べ直す。
public struct OCRLineAssembler {
    /// 2 つの塊の縦の重なりが、低い方の高さのこの割合以上なら同じ行とみなす
    let overlapRatio: CGFloat = 0.5

    public init() {}

    public func assemble(_ blocks: [RecognizedBlock]) -> String {
        let sorted = blocks
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.box.midY > $1.box.midY }  // 上から
        var lines: [[RecognizedBlock]] = []
        for block in sorted {
            if let last = lines.indices.last, isSameLine(block, lines[last]) {
                lines[last].append(block)
            } else {
                lines.append([block])
            }
        }
        return lines
            .map { line in line.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    /// 行の中の塊のどれかと、縦に十分重なっていれば同じ行
    private func isSameLine(_ block: RecognizedBlock, _ line: [RecognizedBlock]) -> Bool {
        line.contains { other in
            let overlap = min(block.box.maxY, other.box.maxY) - max(block.box.minY, other.box.minY)
            let lower = min(block.box.height, other.box.height)
            return lower > 0 && overlap >= lower * overlapRatio
        }
    }
}
