import Foundation

/// 分割のやり方。ページ数が分かったときに、出力 1 つ分ずつのページの範囲（1 から数える）にする
public enum SplitPlan: Equatable, Sendable {
    /// 1 ページずつ（10 ページ → 10 ファイル）
    case eachPage
    /// N ページごと（3 なら 1〜3・4〜6・…。最後は余りのページ）
    case everyPages(Int)
    /// 書いた範囲（例: "1-3, 4-7, 8-10"）。書いた順に 1 つずつのファイルになる
    case ranges(String)
    /// 「このページの後で切る」ページの番号（1 から）。切れ目の間が 1 つずつのファイルになる
    case cuts(Set<Int>)

    /// 出力 1 つ分ずつのページの範囲。範囲が読めない・ページ数を超えるときは EngineError.invalidPageRanges
    public func ranges(pageCount: Int) throws -> [ClosedRange<Int>] {
        guard pageCount > 0 else { throw EngineError.invalidPageRanges(reason: "ページがありません") }
        switch self {
        case .eachPage:
            return Self.chunks(of: 1, pageCount: pageCount)
        case .everyPages(let size):
            guard size >= 1 else { throw EngineError.invalidPageRanges(reason: "何ページごとに分けるかは 1 以上にしてください") }
            return Self.chunks(of: size, pageCount: pageCount)
        case .ranges(let text):
            return try PageRangeParser.parse(text, pageCount: pageCount)
        case .cuts(let cuts):
            var ranges: [ClosedRange<Int>] = []
            var start = 1
            for cut in cuts.sorted() where cut >= start && cut < pageCount {
                ranges.append(start...cut)
                start = cut + 1
            }
            ranges.append(start...pageCount)
            return ranges
        }
    }

    /// 同じ大きさで先頭から区切ったときの「1 つ分のページ数」（qpdf の --split-pages でまとめて分けられる形）。
    /// そうでなければ nil
    public static func uniformChunkSize(of ranges: [ClosedRange<Int>], pageCount: Int) -> Int? {
        guard let first = ranges.first, first.lowerBound == 1 else { return nil }
        let size = first.count
        return ranges == chunks(of: size, pageCount: pageCount) ? size : nil
    }

    private static func chunks(of size: Int, pageCount: Int) -> [ClosedRange<Int>] {
        stride(from: 1, through: pageCount, by: size).map { $0...min($0 + size - 1, pageCount) }
    }
}
