/// ヘルプの項目 1 つ分。
/// 説明の文章は、この型と `Topics/` の各ファイル（項目 1 つに 1 ファイル）にだけ書く。
/// MEMO(2026-11-26・by claude): 操作のカードに「説明」ボタンを付ける案は、村田さん「付ける必要はない」で外した。ヘルプはメニューからだけ開く。
/// MEMO(2026-11-26・by claude): 計画 G。Apple の正式なヘルプ（Help Book）は作りが重く、表示する窓も古いので使わず、SwiftUI の窓で見せる。
/// 新しい操作（分割など）や機能を作ったら、ここにも項目や説明を足す。
struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: HelpIcon
    /// 見出しの下の一言
    let lead: String
    /// 見た目・大きさが変わるか（操作の項目だけ）
    var effects: [HelpEffect] = []
    /// 文章の他に出す図やボタン
    var attachment: HelpAttachment? = nil
    let sections: [HelpSection]

    /// ヘルプの窓の id（メニューの「ヘルプ」から開く）
    static let windowID = "help"
    /// 開いている項目を覚えておく設定の名前（次に開いたときも同じ項目を出す）
    static let selectionKey = "helpTopic"

    /// 操作の項目の id
    static func id(for operation: Operation) -> String {
        "operation." + operation.rawValue
    }

    /// 全部の項目（並びはサイドバーの順）
    static var all: [HelpTopic] {
        HelpTopicGroup.all.flatMap(\.topics)
    }

    /// id から項目を探す。見つからなければ「はじめに」
    static func find(_ id: String?) -> HelpTopic {
        all.first { $0.id == id } ?? introduction
    }
}
