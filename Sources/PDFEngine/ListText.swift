import Foundation

/// いくつかの語を 1 つの文にする（日本語は「、」・「・」、英語は「, 」）。
/// MEMO(2026-11-27・by claude): 英語版（計画 A）。区切りの記号も言語で変わるので、ここに集める。
public enum ListText {
    /// ファイル名などを並べる（日本語「A、B」・英語「A, B」）
    public static func join(_ items: [String]) -> String {
        items.joined(separator: String(localized: "list.separator", defaultValue: "、", bundle: .engine))
    }

    /// 箇条書きの行の頭（日本語「・」・英語「• 」）
    public static var bullet: String {
        String(localized: "list.bullet", defaultValue: "・", bundle: .engine)
    }

    /// 短い語や番号を並べる（日本語「1・3・5」・英語「1, 3, 5」）
    public static func joinShort(_ items: [String]) -> String {
        items.joined(separator: String(localized: "list.separator.short", defaultValue: "・", bundle: .engine))
    }
}
