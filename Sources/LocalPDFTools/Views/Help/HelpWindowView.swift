import SwiftUI

/// ヘルプの窓: 左に項目の一覧、右に説明。左上の欄で、ヘルプの中を探せる。
/// 開いている項目は設定（HelpTopic.selectionKey）に覚えておき、次に開いたときも同じ項目を出す
struct HelpWindowView: View {
    @AppStorage(HelpTopic.selectionKey) private var selection: String?
    /// 検索の欄に入れた文字（窓を閉じたら忘れる）
    @State private var query = ""
    /// 検索の一覧で選んだ所
    @State private var hitSelection: HelpSearchHit.ID?

    var body: some View {
        let terms = HelpSearch.terms(of: query)
        let hits = HelpSearch.hits(for: query)
        let hit = terms.isEmpty ? nil : hits.first { $0.id == hitSelection }
        NavigationSplitView {
            Group {
                if terms.isEmpty {
                    topicList
                } else {
                    HelpSearchResults(hits: hits, terms: terms, selection: $hitSelection)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 300)
        } detail: {
            if let hit {
                HelpTopicView(topic: hit.topic, terms: terms, focusSection: hit.sectionIndex)
            } else {
                HelpTopicView(topic: HelpTopic.find(selection), terms: terms)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: Text("ヘルプを検索"))
        // 検索の一覧で選んだ項目は、検索をやめた後もそのまま開いておく
        .onChange(of: hitSelection) { _, id in
            if let topic = hits.first(where: { $0.id == id })?.topic { selection = topic.id }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private var topicList: some View {
        List(selection: $selection) {
            ForEach(HelpTopicGroup.all) { group in
                Section(group.title) {
                    ForEach(group.topics) { topic in
                        Label {
                            Text(topic.title)
                        } icon: {
                            SymbolTile(symbol: topic.icon.symbolName, color: topic.icon.color, size: 20)
                        }
                        .tag(topic.id)
                    }
                }
            }
        }
    }
}

#Preview {
    HelpWindowView()
        .frame(width: 880, height: 640)
}
