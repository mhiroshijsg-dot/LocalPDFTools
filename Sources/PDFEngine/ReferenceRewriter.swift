/// qpdf の JSON（version 2）の値の中の参照（"5 0 R"）を、対応表のとおりに付け替える。
/// 文字列は "u:…" や "b:…"、名前は "/…" の形なので、参照と取り違えることはない
struct ReferenceRewriter {
    /// 付け替える前の番号 → 付け替えた先の番号
    let map: [String: String]

    func rewrite(_ value: Any) -> Any {
        switch value {
        case let text as String: return map[text] ?? text
        case let array as [Any]: return array.map(rewrite)
        case let dictionary as [String: Any]: return dictionary.mapValues(rewrite)
        default: return value
        }
    }

    /// 付け替える参照が中に 1 つでもあるか
    func touches(_ value: Any) -> Bool {
        switch value {
        case let text as String: return map[text] != nil
        case let array as [Any]: return array.contains(where: touches)
        case let dictionary as [String: Any]: return dictionary.values.contains(where: touches)
        default: return false
        }
    }
}
