import SwiftUI

/// ヘルプの窓: 左に項目の一覧、右に説明。
/// 開いている項目は設定（HelpTopic.selectionKey）に覚えておき、次に開いたときも同じ項目を出す
struct HelpWindowView: View {
    @AppStorage(HelpTopic.selectionKey) private var selection: String?

    var body: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            HelpTopicView(topic: HelpTopic.find(selection))
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

#Preview {
    HelpWindowView()
        .frame(width: 880, height: 640)
}
