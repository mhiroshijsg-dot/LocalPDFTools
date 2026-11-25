import Foundation

/// 画面に出すお知らせ（エラー・警告は赤字）
struct UserMessage: Identifiable, Equatable {
    enum Kind { case error, warning, note }

    let id = UUID()
    let kind: Kind
    let text: String

    static func error(_ text: String) -> UserMessage { UserMessage(kind: .error, text: text) }
    static func warning(_ text: String) -> UserMessage { UserMessage(kind: .warning, text: text) }
    static func note(_ text: String) -> UserMessage { UserMessage(kind: .note, text: text) }
}
