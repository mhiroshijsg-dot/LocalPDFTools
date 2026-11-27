/// ヘルプの窓のサイドバーの見出しと、その下に並ぶ項目
struct HelpTopicGroup: Identifiable {
    let title: String
    let topics: [HelpTopic]

    var id: String { title }

    static let all: [HelpTopicGroup] = [
        HelpTopicGroup(title: String(localized: "使い方"), topics: [.introduction, .flow, .order]),
        HelpTopicGroup(title: String(localized: "操作"), topics: Operation.allCases.map(HelpTopic.operation)),
        HelpTopicGroup(title: String(localized: "そのほか"), topics: [.faq, .components]),
    ]
}

extension HelpTopic {
    /// 操作ごとの項目
    static func operation(_ operation: Operation) -> HelpTopic {
        switch operation {
        case .decrypt: return .decrypt
        case .rotate: return .rotate
        case .merge: return .merge
        case .split: return .split
        case .compress: return .compress
        case .text: return .text
        }
    }
}
