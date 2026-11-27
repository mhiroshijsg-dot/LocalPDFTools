/// ヘルプの検索で見つかった所 1 つ（項目の頭か、項目の中の段落のまとまり 1 つ）
struct HelpSearchHit: Identifiable, Hashable {
    let topic: HelpTopic
    /// 見つかった段落のまとまりの番号。項目の名前・一言・札で見つかったときは nil
    let sectionIndex: Int?
    /// 一覧に出す見出し（段落のまとまりの見出し。項目の頭なら項目の名前）
    let heading: String
    /// 見つかった語の前後の文（一覧に出す）
    let snippet: String

    var id: String { "\(topic.id)#\(sectionIndex ?? -1)" }
}
