import Foundation

/// 「1-3, 5, 8-」のように書いたページの範囲を読む。
/// 区切りは「,」「、」・空白・改行。範囲の印は「-」「〜」など（前後の空白は無視）。全角の数字も読む。「8-」は 8 ページから最後まで
public enum PageRangeParser {
    private static let dashes: Set<Character> = ["-", "‐", "−", "–", "—", "〜", "~", "～", "ー"]

    public static func parse(_ text: String, pageCount: Int) throws -> [ClosedRange<Int>] {
        let halfwidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let unified = String(halfwidth.map { dashes.contains($0) ? "-" : $0 })
            .replacingOccurrences(of: "、", with: ",")
            // 全角を半角にする変換で「、」は半角の「､」になる
            .replacingOccurrences(of: "､", with: ",")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: #"\s*-\s*"#, with: "-", options: .regularExpression)
        let items = unified
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)
        guard !items.isEmpty else {
            throw EngineError.invalidPageRanges(reason: "範囲を書いてください（例: 1-3, 4-7）")
        }
        return try items.map { try range(of: $0, pageCount: pageCount) }
    }

    private static func range(of item: String, pageCount: Int) throws -> ClosedRange<Int> {
        let pieces = item.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        let range: ClosedRange<Int>
        switch pieces.count {
        case 1:
            let page = try number(pieces[0], in: item)
            range = page...page
        case 2:
            let start = try number(pieces[0], in: item)
            let end = pieces[1].isEmpty ? pageCount : try number(pieces[1], in: item)
            guard start <= end else {
                throw EngineError.invalidPageRanges(reason: "「\(item)」は始めのページが終わりより後です")
            }
            range = start...end
        default:
            throw EngineError.invalidPageRanges(reason: "「\(item)」が読めません")
        }
        guard range.lowerBound >= 1, range.upperBound <= pageCount else {
            throw EngineError.invalidPageRanges(reason: "「\(item)」はページの外です（全部で \(pageCount) ページ）")
        }
        return range
    }

    private static func number(_ text: String, in item: String) throws -> Int {
        guard let value = Int(text) else {
            throw EngineError.invalidPageRanges(reason: "「\(item)」が読めません")
        }
        return value
    }
}
