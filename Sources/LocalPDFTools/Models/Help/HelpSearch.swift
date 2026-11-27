import Foundation

/// ヘルプの中を探す。表示中の言語の文（HelpTopic・HelpSection が持つ訳した後の文字）で探す。
/// MEMO(2026-11-27・by claude): 村田さん「ヘルプ画面を開いた後に検索できるようにして欲しい」。
/// 空白で区切った語が「すべて」入っている所（項目の頭、または段落のまとまり 1 つ）を見つける。
/// 大文字と小文字・全角と半角・アクセントの違いは無視する（「ＰＤＦ」でも「pdf」でも見つかる）
enum HelpSearch {
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    /// 一覧に出す文の、見つかった語より前の文字数と、全体の文字数の目安
    private static let snippetLead = 20
    private static let snippetLength = 90

    /// 入れた文字を語に分ける（全角の空白でも区切る）
    static func terms(of query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func hits(for query: String, in topics: [HelpTopic] = HelpTopic.all) -> [HelpSearchHit] {
        let terms = terms(of: query)
        guard !terms.isEmpty else { return [] }
        var hits: [HelpSearchHit] = []
        for topic in topics {
            let effects = topic.effects.map { "\($0.label): \($0.value)" }
            if contains(([topic.title, topic.lead] + effects).joined(separator: "\n"), all: terms) {
                let body = ([topic.lead] + effects).joined(separator: " ")
                hits.append(HelpSearchHit(topic: topic, sectionIndex: nil, heading: topic.title,
                                          snippet: snippet(of: body, around: terms)))
            }
            for (index, section) in topic.sections.enumerated() {
                let body = (section.paragraphs + section.bullets).map(plain).joined(separator: " ")
                guard contains(section.heading + "\n" + body, all: terms) else { continue }
                hits.append(HelpSearchHit(topic: topic, sectionIndex: index, heading: section.heading,
                                          snippet: snippet(of: body, around: terms)))
            }
        }
        return hits
    }

    /// **太字**・`命令`・[リンク](URL) の印を外した文字（印の文字で見つからないように）
    static func plain(_ text: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let styled = try? AttributedString(markdown: text, options: options) else { return text }
        return String(styled.characters)
    }

    private static func contains(_ text: String, all terms: [String]) -> Bool {
        terms.allSatisfy { text.range(of: $0, options: options) != nil }
    }

    /// 一番前で見つかった語の少し前から切り出す。語が無ければ（見出しだけで見つかったとき）頭から
    static func snippet(of text: String, around terms: [String]) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = terms.compactMap { text.range(of: $0, options: options)?.lowerBound }.min() ?? text.startIndex
        var start = text.index(first, offsetBy: -snippetLead, limitedBy: text.startIndex) ?? text.startIndex
        var end = text.index(start, offsetBy: snippetLength, limitedBy: text.endIndex) ?? text.endIndex
        // 英語は語の途中で切らない（空白で切る。日本語のように空白が無ければそのまま）
        if start > text.startIndex, let space = text[start..<first].firstIndex(of: " ") {
            start = text.index(after: space)
        }
        if end < text.endIndex, let space = text[first..<end].lastIndex(of: " ") {
            end = space
        }
        let piece = text[start..<end].trimmingCharacters(in: .whitespaces)
        return (start > text.startIndex ? "…" : "") + piece + (end < text.endIndex ? "…" : "")
    }
}
