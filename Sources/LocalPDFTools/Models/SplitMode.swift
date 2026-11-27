/// 分割の分け方（カードとシートの選ぶ欄に並ぶもの）
enum SplitMode: String, CaseIterable, Identifiable {
    case eachPage, everyPages, ranges, cuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eachPage: return String(localized: "1 ページずつ")
        case .everyPages: return String(localized: "N ページごと")
        case .ranges: return String(localized: "範囲を書く")
        case .cuts: return String(localized: "切れ目を選ぶ")
        }
    }

    /// PDF が 1 つのときだけ使える分け方（範囲や切れ目はファイルごとにページが違うため）
    var needsSingleFile: Bool { self == .ranges || self == .cuts }
}
