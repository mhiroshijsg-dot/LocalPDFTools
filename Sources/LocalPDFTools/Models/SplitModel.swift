import Foundation
import Observation
import PDFEngine

/// 分割のやり方の選択（カードとシートで同じものを使う）
@MainActor
@Observable
final class SplitModel {
    var mode: SplitMode = .eachPage
    /// 「N ページごと」の N
    var pagesPerFile = 2
    /// 「範囲を書く」の文字（例: 1-3, 4-7, 8-）
    var rangeText = ""
    /// 「切れ目を選ぶ」: このページの後で切る、のページ番号（1 から）
    var cuts: Set<Int> = []

    /// 処理の部品に渡す形
    var plan: SplitPlan {
        switch mode {
        case .eachPage: return .eachPage
        case .everyPages: return .everyPages(pagesPerFile)
        case .ranges: return .ranges(rangeText)
        case .cuts: return .cuts(cuts)
        }
    }

    /// ページ数が pageCount の PDF を分けたときの、ファイルごとのページの範囲。指定が正しくなければ理由
    func ranges(pageCount: Int) -> Result<[ClosedRange<Int>], EngineError> {
        do {
            return .success(try plan.ranges(pageCount: pageCount))
        } catch let error as EngineError {
            return .failure(error)
        } catch {
            return .failure(.invalidPageRanges(reason: error.localizedDescription))
        }
    }

    /// 縮小表示のページの間をクリックしたとき: そのページの後の切れ目を付け外しする。
    /// 「1 ページずつ」「N ページごと」から押したときは、今の切れ目を引き継いで「切れ目を選ぶ」に切り替える
    func toggleCut(after page: Int, pageCount: Int) {
        guard page >= 1, page < pageCount, mode != .ranges else { return }
        if mode != .cuts, case .success(let current) = ranges(pageCount: pageCount) {
            cuts = Set(current.dropLast().map(\.upperBound))
            mode = .cuts
        }
        if cuts.contains(page) { cuts.remove(page) } else { cuts.insert(page) }
    }

    /// 入れた PDF が変わったら、切れ目は前のファイルのものなので捨てる
    func forgetCuts() {
        cuts = []
    }
}
