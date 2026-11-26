/// 操作の項目の上に出す「見た目・大きさへの影響」の札 1 枚（例: 「画質: 変わらない」）
struct HelpEffect: Hashable {
    let label: String
    let value: String
    /// 気を付けてほしい変化なら true（札を橙にする）。変わらない・望みどおりの変化なら false（緑）
    var isCaution = false
}
