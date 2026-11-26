/// ヘルプの項目の中の 1 つの段落のまとまり（見出し・文・箇条書き）。
/// 文と箇条書きでは **太字** と [リンク](https://…) が使える
struct HelpSection: Hashable {
    let heading: String
    var paragraphs: [String] = []
    var bullets: [String] = []
}
