import Foundation

/// ヘルプの項目の中の 1 つの段落のまとまり（見出し・文・箇条書き）。
/// 文と箇条書きでは **太字** と [リンク](https://…) が使える
/// MEMO(2026-11-27・by claude): 英語版（計画 A）。文は訳せる形（LocalizedStringResource）で受け取り、
/// 表示中の言語の文字にして持つ（検索でもこの文字を使う）。1 つの文は 1 つのリテラルで書く（`+` でつなぐと訳の鍵が作れない）。
struct HelpSection: Hashable {
    let heading: String
    let paragraphs: [String]
    let bullets: [String]

    init(heading: LocalizedStringResource,
         paragraphs: [LocalizedStringResource] = [],
         bullets: [LocalizedStringResource] = []) {
        self.heading = String(localized: heading)
        self.paragraphs = paragraphs.map { String(localized: $0) }
        self.bullets = bullets.map { String(localized: $0) }
    }
}
