import Foundation

/// ページごとに「時計回りに何回 90° 回すか」（今の向きからの追加分。0〜3）
public struct RotationPlan: Equatable, Sendable {
    public private(set) var quarterTurns: [Int]

    public init(pageCount: Int) {
        quarterTurns = Array(repeating: 0, count: pageCount)
    }

    /// ページごとの回数をそのまま渡して作る（0〜3 に丸める）
    public init(quarterTurns: [Int]) {
        self.quarterTurns = quarterTurns.map(Self.normalized)
    }

    /// 結合した後の PDF 用に、ファイルごとの指定を通しのページ番号につなげる。
    /// pageCounts は各ファイルの実際のページ数。指定の方が短ければ「回さない」で埋め、長ければ切る。
    public static func joined(_ plans: [RotationPlan], pageCounts: [Int]) -> RotationPlan {
        var turns: [Int] = []
        for (plan, count) in zip(plans, pageCounts) {
            let own = Array(plan.quarterTurns.prefix(count))
            turns += own + Array(repeating: 0, count: count - own.count)
        }
        return RotationPlan(quarterTurns: turns)
    }

    public var pageCount: Int { quarterTurns.count }
    public var hasChanges: Bool { quarterTurns.contains { $0 != 0 } }

    /// turns は正なら時計回り、負なら反時計回り
    public mutating func rotate(pageIndex: Int, by turns: Int) {
        guard quarterTurns.indices.contains(pageIndex) else { return }
        quarterTurns[pageIndex] = Self.normalized(quarterTurns[pageIndex] + turns)
    }

    public mutating func rotateAll(by turns: Int) {
        for index in quarterTurns.indices {
            rotate(pageIndex: index, by: turns)
        }
    }

    public mutating func reset() {
        quarterTurns = Array(repeating: 0, count: quarterTurns.count)
    }

    /// qpdf の引数。例: ["--rotate=+90:1,3", "--rotate=+180:2"]（ページ番号は 1 から）
    public func qpdfArguments() -> [String] {
        var arguments: [String] = []
        for turns in 1...3 {
            let pages = quarterTurns.indices.filter { quarterTurns[$0] == turns }.map { String($0 + 1) }
            if !pages.isEmpty {
                arguments.append("--rotate=+\(turns * 90):" + pages.joined(separator: ","))
            }
        }
        return arguments
    }

    private static func normalized(_ turns: Int) -> Int {
        ((turns % 4) + 4) % 4
    }
}
