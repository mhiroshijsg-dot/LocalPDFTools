import SwiftUI

/// ヘルプの窓の左側（検索しているとき）: 見つかった所を項目ごとにまとめた一覧。押すと右にその説明を出す
struct HelpSearchResults: View {
    let hits: [HelpSearchHit]
    let terms: [String]
    @Binding var selection: HelpSearchHit.ID?

    var body: some View {
        if hits.isEmpty {
            ContentUnavailableView.search(text: terms.joined(separator: " "))
        } else {
            List(selection: $selection) {
                ForEach(topics) { topic in
                    Section(topic.title) {
                        ForEach(hits.filter { $0.topic.id == topic.id }) { hit in
                            row(hit).tag(hit.id)
                        }
                    }
                }
            }
        }
    }

    /// 見つかった項目（サイドバーの順のまま、重なりなし）
    private var topics: [HelpTopic] {
        var seen: Set<String> = []
        return hits.map(\.topic).filter { seen.insert($0.id).inserted }
    }

    private func row(_ hit: HelpSearchHit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            SymbolTile(symbol: hit.topic.icon.symbolName, color: hit.topic.icon.color, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(HelpHighlight.apply(terms, to: hit.heading))
                    .lineLimit(2)
                if !hit.snippet.isEmpty {
                    Text(HelpHighlight.apply(terms, to: hit.snippet))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
