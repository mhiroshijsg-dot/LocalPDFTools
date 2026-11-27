import Foundation

/// エンジン（PDFEngine.framework）の文の訳を引く場所。
/// MEMO(2026-11-27・by claude): 英語版（計画 A）。エンジンの文はフレームワーク自身の Localizable.xcstrings にあるので、
/// `String(localized: "…", bundle: .engine)` で引く（アプリの Bundle には無い）。
final class EngineBundle {
    private init() {}
}

extension Bundle {
    static let engine = Bundle(for: EngineBundle.self)
}
